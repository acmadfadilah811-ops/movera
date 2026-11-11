import { ConflictException, Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { Role, User, UserStatus } from '@prisma/client';
import * as bcrypt from 'bcryptjs';
import { createHash, randomBytes } from 'crypto';
import { AuditService } from '../../common/audit.service';
import { PrismaService } from '../../common/prisma.service';
import { LoginDto, RegisterDto } from './auth.dto';

const BCRYPT_COST = 12;

export interface TokenPair {
  accessToken: string;
  refreshToken: string;
  expiresIn: number;
}

export function publicUser(u: User) {
  return { id: u.id, email: u.email, phone: u.phone, fullName: u.fullName, roles: u.roles, status: u.status };
}

const sha256 = (s: string) => createHash('sha256').update(s).digest('hex');

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwt: JwtService,
    private readonly config: ConfigService,
    private readonly audit: AuditService,
  ) {}

  hashPassword(password: string) {
    return bcrypt.hash(password, BCRYPT_COST);
  }

  /** Pendaftaran mandiri hanya untuk pelanggan. Akun driver dan admin dibuat oleh admin. */
  async register(dto: RegisterDto) {
    const email = dto.email.trim().toLowerCase();
    const exists = await this.prisma.user.findFirst({
      where: { OR: [{ email }, ...(dto.phone ? [{ phone: dto.phone }] : [])] },
    });
    if (exists) throw new ConflictException('Email atau nomor HP sudah terdaftar.');
    const user = await this.prisma.user.create({
      data: {
        email,
        phone: dto.phone,
        fullName: dto.fullName.trim(),
        passwordHash: await this.hashPassword(dto.password),
        roles: [Role.CUSTOMER],
      },
    });
    await this.audit.log({ actorId: user.id, action: 'auth.register', entity: 'user', entityId: user.id });
    return { user: publicUser(user), ...(await this.issueTokens(user)) };
  }

  async login(dto: LoginDto) {
    const user = await this.prisma.user.findUnique({ where: { email: dto.email.trim().toLowerCase() } });
    // Pesan sama untuk email salah dan sandi salah supaya akun tidak bisa ditebak.
    const ok = user ? await bcrypt.compare(dto.password, user.passwordHash) : false;
    if (!user || !ok) throw new UnauthorizedException('Email atau kata sandi salah.');
    if (user.status !== UserStatus.ACTIVE) throw new UnauthorizedException('Akun dinonaktifkan. Hubungi Movera.');
    return { user: publicUser(user), ...(await this.issueTokens(user)) };
  }

  /** Rotasi refresh token. Token lama yang dipakai ulang mencabut semua sesi pengguna itu. */
  async refresh(refreshToken: string) {
    const row = await this.prisma.refreshToken.findUnique({
      where: { tokenHash: sha256(refreshToken) },
      include: { user: true },
    });
    if (!row) throw new UnauthorizedException('Sesi tidak valid.');
    if (row.revokedAt) {
      await this.prisma.refreshToken.updateMany({
        where: { userId: row.userId, revokedAt: null },
        data: { revokedAt: new Date() },
      });
      await this.audit.log({ actorId: row.userId, action: 'auth.refresh_reuse', entity: 'user', entityId: row.userId });
      throw new UnauthorizedException('Sesi tidak valid. Silakan login ulang.');
    }
    if (row.expiresAt < new Date() || row.user.status !== UserStatus.ACTIVE) {
      throw new UnauthorizedException('Sesi sudah berakhir. Silakan login ulang.');
    }
    await this.prisma.refreshToken.update({ where: { id: row.id }, data: { revokedAt: new Date() } });
    return { user: publicUser(row.user), ...(await this.issueTokens(row.user)) };
  }

  async logout(refreshToken: string) {
    await this.prisma.refreshToken.updateMany({
      where: { tokenHash: sha256(refreshToken), revokedAt: null },
      data: { revokedAt: new Date() },
    });
  }

  async me(userId: string) {
    const user = await this.prisma.user.findUniqueOrThrow({ where: { id: userId } });
    return publicUser(user);
  }

  private async issueTokens(user: User): Promise<TokenPair> {
    const accessTtl = Number(this.config.get('JWT_ACCESS_TTL') ?? 900);
    const refreshTtl = Number(this.config.get('JWT_REFRESH_TTL') ?? 2592000);
    const accessToken = await this.jwt.signAsync(
      { sub: user.id, roles: user.roles, typ: 'access' },
      { secret: this.config.getOrThrow<string>('JWT_ACCESS_SECRET'), expiresIn: accessTtl, algorithm: 'HS256' },
    );
    const refreshToken = randomBytes(48).toString('base64url');
    await this.prisma.refreshToken.create({
      data: { userId: user.id, tokenHash: sha256(refreshToken), expiresAt: new Date(Date.now() + refreshTtl * 1000) },
    });
    return { accessToken, refreshToken, expiresIn: accessTtl };
  }
}

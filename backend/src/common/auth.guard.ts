import { CanActivate, ExecutionContext, ForbiddenException, Injectable, UnauthorizedException } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { Role } from '@prisma/client';
import { AuthUser, IS_PUBLIC, ROLES } from './auth.decorators';

/** Semua endpoint wajib login kecuali ditandai @Public(). Peran dicek lewat @Roles(). */
@Injectable()
export class AuthGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly jwt: JwtService,
    private readonly config: ConfigService,
  ) {}

  async canActivate(ctx: ExecutionContext): Promise<boolean> {
    const targets = [ctx.getHandler(), ctx.getClass()];
    if (this.reflector.getAllAndOverride<boolean>(IS_PUBLIC, targets)) return true;

    const req = ctx.switchToHttp().getRequest();
    const header: string | undefined = req.headers?.authorization;
    const token = header?.startsWith('Bearer ') ? header.slice(7) : undefined;
    if (!token) throw new UnauthorizedException('Silakan login terlebih dahulu.');

    let user: AuthUser;
    try {
      const payload = await this.jwt.verifyAsync<{ sub: string; roles: Role[]; typ: string }>(token, {
        secret: this.config.getOrThrow<string>('JWT_ACCESS_SECRET'),
        algorithms: ['HS256'],
      });
      if (payload.typ !== 'access') throw new Error('bukan access token');
      user = { id: payload.sub, roles: payload.roles };
    } catch {
      throw new UnauthorizedException('Sesi tidak valid atau sudah berakhir.');
    }
    req.user = user;

    const required = this.reflector.getAllAndOverride<Role[]>(ROLES, targets);
    if (required?.length && !user.roles.includes(Role.SUPER_ADMIN) && !required.some((r) => user.roles.includes(r))) {
      throw new ForbiddenException('Anda tidak punya akses ke fitur ini.');
    }
    return true;
  }
}

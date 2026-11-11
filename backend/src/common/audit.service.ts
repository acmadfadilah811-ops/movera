import { Global, Injectable, Module } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from './prisma.service';

type Tx = Prisma.TransactionClient | PrismaService;

/** Catatan audit untuk operasi sensitif (blueprint bagian 14). */
@Injectable()
export class AuditService {
  constructor(private readonly prisma: PrismaService) {}

  log(entry: { actorId?: string | null; action: string; entity: string; entityId?: string; data?: Prisma.InputJsonValue }, tx?: Tx) {
    return (tx ?? this.prisma).auditLog.create({
      data: { actorId: entry.actorId ?? null, action: entry.action, entity: entry.entity, entityId: entry.entityId, data: entry.data },
    });
  }
}

@Global()
@Module({ providers: [AuditService], exports: [AuditService] })
export class AuditModule {}

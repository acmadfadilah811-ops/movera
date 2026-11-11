import { ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import { AppModule } from './app.module';

export function configureApp(app: Awaited<ReturnType<typeof NestFactory.create>>) {
  app.setGlobalPrefix('api/v1');
  app.useGlobalPipes(new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true }));
  app.enableShutdownHooks();
}

async function bootstrap() {
  for (const key of ['DATABASE_URL', 'JWT_ACCESS_SECRET']) {
    if (!process.env[key]) throw new Error(`${key} belum diisi di .env`);
  }
  const app = await NestFactory.create(AppModule);
  configureApp(app);
  app.enableCors({ origin: process.env.CORS_ORIGIN?.split(',') ?? false });
  if (process.env.NODE_ENV !== 'production') {
    const doc = SwaggerModule.createDocument(app, new DocumentBuilder().setTitle('Movera API').setVersion('0.1').addBearerAuth().build());
    SwaggerModule.setup('api/docs', app, doc);
  }
  await app.listen(Number(process.env.PORT ?? 3000));
}

if (require.main === module) void bootstrap();

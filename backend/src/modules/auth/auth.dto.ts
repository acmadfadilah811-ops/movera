import { IsEmail, IsOptional, IsString, Length, Matches, MinLength } from 'class-validator';

export class RegisterDto {
  @IsEmail({}, { message: 'Email tidak valid.' })
  email: string;

  @IsString()
  @MinLength(8, { message: 'Kata sandi minimal 8 karakter.' })
  password: string;

  @IsString()
  @Length(2, 100, { message: 'Nama 2-100 karakter.' })
  fullName: string;

  @IsOptional()
  @Matches(/^\+?\d{9,15}$/, { message: 'Nomor HP tidak valid.' })
  phone?: string;
}

export class LoginDto {
  @IsEmail({}, { message: 'Email tidak valid.' })
  email: string;

  @IsString()
  password: string;
}

export class RefreshDto {
  @IsString()
  refreshToken: string;
}

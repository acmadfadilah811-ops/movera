import { BadRequestException, Body, Controller, Delete, Get, HttpCode, Injectable, Module, NotFoundException, Param, ParseUUIDPipe, Post, Put } from '@nestjs/common';
import { Role } from '@prisma/client';
import { IsBoolean, IsLatitude, IsLongitude, IsOptional, IsString, Length, Matches, MaxLength } from 'class-validator';
import { AuthUser, CurrentUser, Roles } from '../../common/auth.decorators';
import { PrismaService } from '../../common/prisma.service';

class AddressDto {
  @IsString()
  @Length(1, 50)
  label: string;

  @IsString()
  @MaxLength(300)
  address: string;

  @IsLatitude()
  latitude: number;

  @IsLongitude()
  longitude: number;
}

class PassengerDto {
  @IsString()
  @Length(1, 100, { message: 'Nama penumpang wajib diisi.' })
  name: string;

  @IsString()
  @MaxLength(30)
  relation: string;

  @IsBoolean()
  isChild: boolean;

  @IsOptional()
  @IsString()
  @MaxLength(100)
  school?: string;

  @IsOptional()
  @IsString()
  @MaxLength(300)
  notes?: string;

  @IsOptional()
  @IsString()
  @MaxLength(100)
  emergencyName?: string;

  @IsOptional()
  @Matches(/^(\+?[\d\s-]{9,20})?$/, { message: 'Nomor HP kontak darurat tidak valid.' })
  emergencyPhone?: string;
}

@Injectable()
export class CustomersService {
  constructor(private readonly prisma: PrismaService) {}

  addresses(userId: string) {
    return this.prisma.customerAddress.findMany({ where: { userId }, orderBy: { createdAt: 'asc' } });
  }

  /** Label sama menimpa alamat lama (misalnya "Rumah"). */
  saveAddress(userId: string, dto: AddressDto) {
    const label = dto.label.trim();
    return this.prisma.customerAddress.upsert({
      where: { userId_label: { userId, label } },
      create: { userId, label, address: dto.address, latitude: dto.latitude, longitude: dto.longitude },
      update: { address: dto.address, latitude: dto.latitude, longitude: dto.longitude },
    });
  }

  async deleteAddress(userId: string, id: string) {
    const r = await this.prisma.customerAddress.deleteMany({ where: { id, userId } });
    if (r.count === 0) throw new NotFoundException('Alamat tidak ditemukan.');
  }

  passengers(userId: string) {
    return this.prisma.passenger.findMany({ where: { userId, deletedAt: null }, orderBy: { createdAt: 'asc' } });
  }

  private validateChild(dto: PassengerDto) {
    if (dto.isChild && (!dto.emergencyName?.trim() || !dto.emergencyPhone?.trim())) {
      throw new BadRequestException('Penumpang anak wajib punya kontak darurat (nama dan nomor HP).');
    }
  }

  private data(dto: PassengerDto) {
    return {
      name: dto.name.trim(),
      relation: dto.relation.trim(),
      isChild: dto.isChild,
      school: dto.isChild ? (dto.school?.trim() ?? '') : '',
      notes: dto.notes?.trim() ?? '',
      emergencyName: dto.emergencyName?.trim() ?? '',
      emergencyPhone: dto.emergencyPhone?.trim() ?? '',
    };
  }

  createPassenger(userId: string, dto: PassengerDto) {
    this.validateChild(dto);
    return this.prisma.passenger.create({ data: { userId, ...this.data(dto) } });
  }

  async updatePassenger(userId: string, id: string, dto: PassengerDto) {
    this.validateChild(dto);
    const r = await this.prisma.passenger.updateMany({ where: { id, userId, deletedAt: null }, data: this.data(dto) });
    if (r.count === 0) throw new NotFoundException('Penumpang tidak ditemukan.');
    return this.prisma.passenger.findUniqueOrThrow({ where: { id } });
  }

  /** Soft delete: booking lama tetap mencantumkan nama penumpang. */
  async deletePassenger(userId: string, id: string) {
    const r = await this.prisma.passenger.updateMany({ where: { id, userId, deletedAt: null }, data: { deletedAt: new Date() } });
    if (r.count === 0) throw new NotFoundException('Penumpang tidak ditemukan.');
  }
}

@Roles(Role.CUSTOMER)
@Controller('me')
export class CustomersController {
  constructor(private readonly customers: CustomersService) {}

  @Get('addresses')
  addresses(@CurrentUser() u: AuthUser) {
    return this.customers.addresses(u.id);
  }

  @Post('addresses')
  saveAddress(@CurrentUser() u: AuthUser, @Body() dto: AddressDto) {
    return this.customers.saveAddress(u.id, dto);
  }

  @HttpCode(204)
  @Delete('addresses/:id')
  deleteAddress(@CurrentUser() u: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.customers.deleteAddress(u.id, id);
  }

  @Get('passengers')
  passengers(@CurrentUser() u: AuthUser) {
    return this.customers.passengers(u.id);
  }

  @Post('passengers')
  createPassenger(@CurrentUser() u: AuthUser, @Body() dto: PassengerDto) {
    return this.customers.createPassenger(u.id, dto);
  }

  @Put('passengers/:id')
  updatePassenger(@CurrentUser() u: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() dto: PassengerDto) {
    return this.customers.updatePassenger(u.id, id, dto);
  }

  @HttpCode(204)
  @Delete('passengers/:id')
  deletePassenger(@CurrentUser() u: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.customers.deletePassenger(u.id, id);
  }
}

@Module({ controllers: [CustomersController], providers: [CustomersService] })
export class CustomersModule {}

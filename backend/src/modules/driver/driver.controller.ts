import { Body, Controller, Get, HttpCode, Module, Param, ParseUUIDPipe, Post } from '@nestjs/common';
import { IncidentType, Role } from '@prisma/client';
import { Type } from 'class-transformer';
import {
  ArrayMinSize,
  IsArray,
  IsBoolean,
  IsDateString,
  IsEnum,
  IsIn,
  IsInt,
  IsLatitude,
  IsLongitude,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  Length,
  Max,
  MaxLength,
  Min,
  ValidateNested,
} from 'class-validator';
import { AuthUser, CurrentUser, Roles } from '../../common/auth.decorators';
import { DriverService } from './driver.service';

class ChecklistItemDto {
  @IsString() @MaxLength(30) key: string;
  @IsString() @MaxLength(100) label: string;
  @IsBoolean() critical: boolean;
  @IsBoolean() ok: boolean;
}

class StartShiftDto {
  @IsArray()
  @ArrayMinSize(1)
  @ValidateNested({ each: true })
  @Type(() => ChecklistItemDto)
  checklist: ChecklistItemDto[];

  @IsInt() @Min(0) @Max(100) batteryPercent: number;
  @IsInt() @Min(0) odometer: number;
}

class StatusDto {
  @IsIn(['BREAK', 'AVAILABLE', 'CHARGING']) status: 'BREAK' | 'AVAILABLE' | 'CHARGING';
}

class BatteryDto {
  @IsInt() @Min(0) @Max(100) batteryPercent: number;
  @IsOptional() @IsBoolean() finishCharging?: boolean;
}

class EndShiftDto {
  @IsInt() @Min(0) @Max(100) batteryPercent: number;
  @IsInt() @Min(0) odometer: number;
  @IsOptional() @IsString() @MaxLength(500) note?: string;
}

class RejectDto {
  @IsString() @Length(3, 200) reason: string;
}

class PinDto {
  @IsString() @Length(4, 4) pin: string;
}

class IncidentDto {
  @IsEnum(IncidentType) type: IncidentType;
  @IsString() @MaxLength(1000) description: string;
  @IsOptional() @IsUUID('4') tripId?: string;
  @IsOptional() @IsBoolean() emergency?: boolean;
}

class LocationDto {
  @IsLatitude() latitude: number;
  @IsLongitude() longitude: number;
  @IsOptional() @IsNumber() @Min(0) accuracy?: number;
  @IsOptional() @IsUUID('4') tripId?: string;
  @IsOptional() @IsDateString() recordedAt?: string;
}

@Roles(Role.DRIVER)
@Controller('driver')
export class DriverController {
  constructor(private readonly driver: DriverService) {}

  @Get('today')
  today(@CurrentUser() u: AuthUser) {
    return this.driver.today(u.id);
  }

  @HttpCode(200)
  @Post('shift/start')
  start(@CurrentUser() u: AuthUser, @Body() dto: StartShiftDto) {
    return this.driver.startShift(u.id, dto);
  }

  @HttpCode(200)
  @Post('shift/status')
  status(@CurrentUser() u: AuthUser, @Body() dto: StatusDto) {
    return this.driver.setStatus(u.id, dto.status);
  }

  @HttpCode(200)
  @Post('shift/battery')
  battery(@CurrentUser() u: AuthUser, @Body() dto: BatteryDto) {
    return this.driver.updateBattery(u.id, dto.batteryPercent, dto.finishCharging ?? false);
  }

  @HttpCode(200)
  @Post('shift/end')
  end(@CurrentUser() u: AuthUser, @Body() dto: EndShiftDto) {
    return this.driver.endShift(u.id, dto);
  }

  @HttpCode(200)
  @Post('trips/:id/accept')
  accept(@CurrentUser() u: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.driver.accept(u.id, id);
  }

  @HttpCode(200)
  @Post('trips/:id/reject')
  reject(@CurrentUser() u: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() dto: RejectDto) {
    return this.driver.reject(u.id, id, dto.reason);
  }

  @HttpCode(200)
  @Post('trips/:id/stops/:stopId/arrive')
  arrive(@CurrentUser() u: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Param('stopId', ParseUUIDPipe) stopId: string) {
    return this.driver.arrive(u.id, id, stopId);
  }

  @HttpCode(200)
  @Post('trips/:id/stops/:stopId/pickup')
  pickup(@CurrentUser() u: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Param('stopId', ParseUUIDPipe) stopId: string, @Body() dto: PinDto) {
    return this.driver.confirmPickup(u.id, id, stopId, dto.pin);
  }

  @HttpCode(200)
  @Post('trips/:id/stops/:stopId/no-show')
  noShow(@CurrentUser() u: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Param('stopId', ParseUUIDPipe) stopId: string) {
    return this.driver.markNoShow(u.id, id, stopId);
  }

  @HttpCode(200)
  @Post('trips/:id/stops/:stopId/dropoff')
  dropoff(@CurrentUser() u: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Param('stopId', ParseUUIDPipe) stopId: string) {
    return this.driver.confirmDropoff(u.id, id, stopId);
  }

  @Post('incidents')
  incident(@CurrentUser() u: AuthUser, @Body() dto: IncidentDto) {
    return this.driver.reportIncident(u.id, dto);
  }

  @HttpCode(200)
  @Post('location')
  location(@CurrentUser() u: AuthUser, @Body() dto: LocationDto) {
    return this.driver.recordLocation(u.id, dto);
  }

  @Get('history')
  history(@CurrentUser() u: AuthUser) {
    return this.driver.history(u.id);
  }
}

@Module({ controllers: [DriverController], providers: [DriverService] })
export class DriverModule {}

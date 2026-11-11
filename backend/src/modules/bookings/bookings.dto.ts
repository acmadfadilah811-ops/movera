import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsDateString,
  IsEnum,
  IsInt,
  IsLatitude,
  IsLongitude,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
  ValidateNested,
} from 'class-validator';
import { BookingType, RideMode } from '@prisma/client';

export class PlaceDto {
  @IsOptional()
  @IsString()
  @MaxLength(50)
  label?: string;

  @IsString()
  @MaxLength(300)
  address: string;

  @IsLatitude()
  latitude: number;

  @IsLongitude()
  longitude: number;
}

export class CreateBookingDto {
  @IsEnum(BookingType)
  type: BookingType;

  @IsEnum(RideMode)
  rideMode: RideMode;

  @ValidateNested()
  @Type(() => PlaceDto)
  pickup: PlaceDto;

  @ValidateNested()
  @Type(() => PlaceDto)
  destination: PlaceDto;

  @IsInt()
  @Min(1)
  @Max(8)
  passengerCount: number;

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(8)
  @IsString({ each: true })
  @MaxLength(100, { each: true })
  passengerNames?: string[];

  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(60)
  maxDetourMinutes?: number;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  note?: string;

  /** Wajib untuk booking FLEXIBLE. ISO 8601 dengan zona waktu, contoh 2026-11-12T07:00:00+07:00. */
  @IsOptional()
  @IsDateString()
  scheduledAt?: string;

  /** Wajib untuk booking ROUTINE. 1 = Senin ... 7 = Minggu. */
  @IsOptional()
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(7)
  @IsInt({ each: true })
  @Min(1, { each: true })
  @Max(7, { each: true })
  weekdays?: number[];

  /** Jam jemput WIB untuk booking ROUTINE. */
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(23)
  hour?: number;

  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(59)
  minute?: number;
}

export class CancelBookingDto {
  @IsString()
  @MaxLength(200)
  reason: string;
}

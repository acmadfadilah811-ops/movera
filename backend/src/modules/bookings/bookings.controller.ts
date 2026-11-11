import { Body, Controller, Delete, Get, HttpCode, Module, Param, ParseUUIDPipe, Post, Query } from '@nestjs/common';
import { Role } from '@prisma/client';
import { AuthUser, CurrentUser, Roles } from '../../common/auth.decorators';
import { CancelBookingDto, CreateBookingDto } from './bookings.dto';
import { BookingsService } from './bookings.service';

@Roles(Role.CUSTOMER)
@Controller()
export class BookingsController {
  constructor(private readonly bookings: BookingsService) {}

  @Post('bookings')
  create(@CurrentUser() user: AuthUser, @Body() dto: CreateBookingDto) {
    return this.bookings.create(user.id, dto);
  }

  @Get('bookings')
  list(@CurrentUser() user: AuthUser, @Query('scope') scope?: 'upcoming' | 'history' | 'all') {
    return this.bookings.list(user.id, scope ?? 'all');
  }

  @Get('bookings/:id')
  detail(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.bookings.detail(user.id, id);
  }

  @HttpCode(200)
  @Post('bookings/:id/cancel')
  cancel(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() dto: CancelBookingDto) {
    return this.bookings.cancel(user.id, id, dto.reason);
  }

  @Get('recurring-schedules')
  schedules(@CurrentUser() user: AuthUser) {
    return this.bookings.listSchedules(user.id);
  }

  @Delete('recurring-schedules/:id')
  deactivate(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.bookings.deactivateSchedule(user.id, id);
  }
}

@Module({ controllers: [BookingsController], providers: [BookingsService], exports: [BookingsService] })
export class BookingsModule {}

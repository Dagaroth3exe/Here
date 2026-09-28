import { Body, Controller, Get, HttpCode, HttpStatus, Param, ParseUUIDPipe, Post, Req, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard.js';
import type { AuthedRequest } from '../auth/jwt-auth.guard.js';
import { EmergencyLocationDto, RaiseEmergencyDto, ResolveEmergencyDto } from './dto/raise-emergency.dto.js';
import { EmergencyService } from './emergency.service.js';

@Controller('emergency')
@UseGuards(JwtAuthGuard)
export class EmergencyController {
  constructor(private readonly emergency: EmergencyService) {}

  /** Raise the alarm (or, with one already open, move it to a new location). */
  @Post()
  raise(@Req() request: AuthedRequest, @Body() dto: RaiseEmergencyDto) {
    return this.emergency.raise(request.userId, dto);
  }

  /** Your own open alarm, or null. */
  @Get('mine')
  mine(@Req() request: AuthedRequest) {
    return this.emergency.mine(request.userId);
  }

  /** Your false alarms, and whether SOS is paused because of them. */
  @Get('standing')
  standing(@Req() request: AuthedRequest) {
    return this.emergency.standing(request.userId);
  }

  @Get(':id')
  get(@Req() request: AuthedRequest, @Param('id', ParseUUIDPipe) id: string) {
    return this.emergency.get(request.userId, id);
  }

  @Post(':id/location')
  location(@Req() request: AuthedRequest, @Param('id', ParseUUIDPipe) id: string, @Body() dto: EmergencyLocationDto) {
    return this.emergency.updateLocation(request.userId, id, dto.lat, dto.lng);
  }

  @Post(':id/resolve')
  @HttpCode(HttpStatus.NO_CONTENT)
  resolve(
    @Req() request: AuthedRequest,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: ResolveEmergencyDto,
  ) {
    return this.emergency.resolve(request.userId, id, dto.falseAlarm ?? false);
  }

  /** Someone alerted says it was a false alarm. */
  @Post(':id/flag')
  flag(@Req() request: AuthedRequest, @Param('id', ParseUUIDPipe) id: string) {
    return this.emergency.flag(request.userId, id);
  }
}

import { Body, Controller, Delete, HttpCode, HttpStatus, Post, Req, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard.js';
import type { AuthedRequest } from '../auth/jwt-auth.guard.js';
import { EndpointDto, RemoveEndpointDto } from './dto/endpoint.dto.js';
import { PushService } from './push.service.js';

@Controller('push')
@UseGuards(JwtAuthGuard)
export class PushController {
  constructor(private readonly push: PushService) {}

  @Post('endpoints')
  @HttpCode(HttpStatus.NO_CONTENT)
  register(@Req() request: AuthedRequest, @Body() dto: EndpointDto) {
    return this.push.register(request.userId, dto.endpoint, dto.p256dh && dto.auth ? { p256dh: dto.p256dh, auth: dto.auth } : null);
  }

  /** On sign-out, so the phone stops getting this user's notifications. */
  @Delete('endpoints')
  @HttpCode(HttpStatus.NO_CONTENT)
  unregister(@Req() request: AuthedRequest, @Body() dto: RemoveEndpointDto) {
    return this.push.unregister(request.userId, dto.endpoint);
  }
}

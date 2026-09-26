import { Body, Controller, Delete, Get, HttpCode, HttpStatus, Param, ParseUUIDPipe, Post, Req, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard.js';
import type { AuthedRequest } from '../auth/jwt-auth.guard.js';
import { BlockDto } from './dto/block.dto.js';
import { ReportDto } from './dto/report.dto.js';
import { SafetyService } from './safety.service.js';

@Controller('safety')
@UseGuards(JwtAuthGuard)
export class SafetyController {
  constructor(private readonly safety: SafetyService) {}

  @Get('blocks')
  blocked(@Req() request: AuthedRequest) {
    return this.safety.listBlocked(request.userId);
  }

  @Post('blocks')
  @HttpCode(HttpStatus.NO_CONTENT)
  block(@Req() request: AuthedRequest, @Body() dto: BlockDto) {
    return this.safety.block(request.userId, dto.userId);
  }

  @Delete('blocks/:userId')
  @HttpCode(HttpStatus.NO_CONTENT)
  unblock(@Req() request: AuthedRequest, @Param('userId', ParseUUIDPipe) userId: string) {
    return this.safety.unblock(request.userId, userId);
  }

  @Post('reports')
  report(@Req() request: AuthedRequest, @Body() dto: ReportDto) {
    return this.safety.report({ reporterId: request.userId, ...dto });
  }
}

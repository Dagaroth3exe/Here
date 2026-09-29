import { Body, Controller, Get, Put, Query, Req, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard.js';
import type { AuthedRequest } from '../auth/jwt-auth.guard.js';
import { AreaService } from './area.service.js';
import { AreaBoundsDto, AreaPreferenceDto, AreaQueryDto } from './dto/area.dto.js';

@Controller('area')
@UseGuards(JwtAuthGuard)
export class AreaController {
  constructor(private readonly area: AreaService) {}

  /** Recent alerts around a point, for the Home screen. */
  @Get('summary')
  summary(@Query() query: AreaQueryDto) {
    return this.area.summary(query.lat, query.lng);
  }

  /** Grid cells with recent alerts inside the visible map box. */
  @Get('heatmap')
  heatmap(@Query() box: AreaBoundsDto) {
    return this.area.heatmap(box);
  }

  @Get('preferences')
  preference(@Req() request: AuthedRequest) {
    return this.area.preference(request.userId);
  }

  @Put('preferences')
  setPreference(@Req() request: AuthedRequest, @Body() dto: AreaPreferenceDto) {
    return this.area.setPreference(request.userId, dto.notices);
  }
}

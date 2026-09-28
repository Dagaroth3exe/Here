import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { AreaQueryDto } from '../area/dto/area.dto.js';
import { JwtAuthGuard } from '../auth/jwt-auth.guard.js';
import { CrimeService } from './crime.service.js';

@Controller('crime')
@UseGuards(JwtAuthGuard)
export class CrimeController {
  constructor(private readonly crime: CrimeService) {}

  /** Official figures for the district containing this point, or null. */
  @Get('district')
  district(@Query() query: AreaQueryDto) {
    return this.crime.forPoint(query.lat, query.lng);
  }
}

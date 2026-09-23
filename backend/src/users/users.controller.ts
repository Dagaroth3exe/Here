import { Controller, Get, Query, Req, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard.js';
import type { AuthedRequest } from '../auth/jwt-auth.guard.js';
import { UsersService } from './users.service.js';

@Controller('users')
@UseGuards(JwtAuthGuard)
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Get('search')
  search(@Req() request: AuthedRequest, @Query('q') q: string | undefined) {
    return this.usersService.search(q ?? '', request.userId);
  }
}

import { Body, Controller, Get, Patch, Query, Req, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard.js';
import type { AuthedRequest } from '../auth/jwt-auth.guard.js';
import { UpdateProfileDto } from './dto/update-profile.dto.js';
import { UsersService } from './users.service.js';

@Controller('users')
@UseGuards(JwtAuthGuard)
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Get('search')
  search(@Req() request: AuthedRequest, @Query('q') q: string | undefined) {
    return this.usersService.search(q ?? '', request.userId);
  }

  @Get('me')
  me(@Req() request: AuthedRequest) {
    return this.usersService.getProfile(request.userId);
  }

  @Patch('me')
  updateMe(@Req() request: AuthedRequest, @Body() body: UpdateProfileDto) {
    return this.usersService.updateProfile(request.userId, body);
  }
}

import { Controller, Delete, HttpCode, Req, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard.js';
import type { AuthedRequest } from '../auth/jwt-auth.guard.js';
import { AccountService } from './account.service.js';

@Controller('account')
@UseGuards(JwtAuthGuard)
export class AccountController {
  constructor(private readonly account: AccountService) {}

  /** Permanently deletes the signed-in account (see [AccountService.delete]). */
  @Delete()
  @HttpCode(204)
  async delete(@Req() request: AuthedRequest): Promise<void> {
    await this.account.delete(request.userId);
  }
}

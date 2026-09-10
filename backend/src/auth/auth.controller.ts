import { Body, Controller, Post } from '@nestjs/common';
import { AuthService } from './auth.service.js';
import { AuthenticationOptionsDto } from './dto/authentication-options.dto.js';
import { AuthenticationVerificationDto } from './dto/authentication-verification.dto.js';
import { RegistrationOptionsDto } from './dto/registration-options.dto.js';
import { RegistrationVerificationDto } from './dto/registration-verification.dto.js';
import { TotpConfirmDto } from './dto/totp-confirm.dto.js';
import { TotpLoginDto } from './dto/totp-login.dto.js';
import { TotpSetupDto } from './dto/totp-setup.dto.js';

@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post('register/options')
  registerOptions(@Body() dto: RegistrationOptionsDto) {
    return this.authService.generateRegistrationOptionsFor(dto.email);
  }

  @Post('register/verify')
  registerVerify(@Body() dto: RegistrationVerificationDto) {
    return this.authService.verifyRegistration(dto.email, dto.response);
  }

  @Post('login/options')
  loginOptions(@Body() dto: AuthenticationOptionsDto) {
    return this.authService.generateAuthenticationOptionsFor(dto.email);
  }

  @Post('login/verify')
  loginVerify(@Body() dto: AuthenticationVerificationDto) {
    return this.authService.verifyAuthentication(dto.email, dto.response);
  }

  @Post('totp/setup')
  totpSetup(@Body() dto: TotpSetupDto) {
    return this.authService.setupTotp(dto.email);
  }

  @Post('totp/confirm')
  totpConfirm(@Body() dto: TotpConfirmDto) {
    return this.authService.confirmTotp(dto.email, dto.code);
  }

  @Post('totp/login')
  totpLogin(@Body() dto: TotpLoginDto) {
    return this.authService.loginWithTotp(dto.email, dto.code);
  }
}

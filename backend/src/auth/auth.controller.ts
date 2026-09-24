import { Body, Controller, Post } from '@nestjs/common';
import { AuthService } from './auth.service.js';
import { AppleSignInDto } from './dto/apple-signin.dto.js';
import { AuthenticationOptionsDto } from './dto/authentication-options.dto.js';
import { AuthenticationVerificationDto } from './dto/authentication-verification.dto.js';
import { GoogleSignInDto } from './dto/google-signin.dto.js';
import { OtpRequestDto } from './dto/otp-request.dto.js';
import { OtpVerifyDto } from './dto/otp-verify.dto.js';
import { PasswordLoginDto } from './dto/password-login.dto.js';
import { PasswordSignupDto } from './dto/password-signup.dto.js';
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

  @Post('password/signup')
  passwordSignup(@Body() dto: PasswordSignupDto) {
    return this.authService.signupWithPassword(dto.name, dto.password);
  }

  @Post('password/login')
  passwordLogin(@Body() dto: PasswordLoginDto) {
    return this.authService.loginWithPassword(dto.name, dto.password);
  }

  @Post('otp/request')
  otpRequest(@Body() dto: OtpRequestDto) {
    return this.authService.requestOtp(dto.phone);
  }

  @Post('otp/verify')
  otpVerify(@Body() dto: OtpVerifyDto) {
    return this.authService.verifyOtp(dto.phone, dto.code);
  }

  @Post('google')
  googleSignIn(@Body() dto: GoogleSignInDto) {
    return this.authService.loginOrSignupWithGoogle(dto.idToken);
  }

  @Post('apple')
  appleSignIn(@Body() dto: AppleSignInDto) {
    return this.authService.loginOrSignupWithApple(dto.idToken, dto.fullName);
  }
}

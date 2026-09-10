import { IsEmail, IsObject } from 'class-validator';
import type { AuthenticationResponseJSON } from '@simplewebauthn/server';

export class AuthenticationVerificationDto {
  @IsEmail()
  email: string;

  @IsObject()
  response: AuthenticationResponseJSON;
}

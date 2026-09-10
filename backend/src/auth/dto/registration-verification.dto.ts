import { IsEmail, IsObject } from 'class-validator';
import type { RegistrationResponseJSON } from '@simplewebauthn/server';

export class RegistrationVerificationDto {
  @IsEmail()
  email: string;

  @IsObject()
  response: RegistrationResponseJSON;
}

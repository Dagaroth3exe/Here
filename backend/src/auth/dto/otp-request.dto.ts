import { IsString, Matches } from 'class-validator';

export class OtpRequestDto {
  @IsString()
  @Matches(/^\+[1-9]\d{7,14}$/, {
    message: 'Enter phone number in international format, e.g. +91...',
  })
  phone: string;
}

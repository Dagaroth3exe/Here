import { IsOptional, IsString } from 'class-validator';

export class AppleSignInDto {
  @IsString()
  idToken: string;

  @IsOptional()
  @IsString()
  fullName?: string;
}

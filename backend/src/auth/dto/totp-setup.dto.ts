import { IsEmail } from 'class-validator';

export class TotpSetupDto {
  @IsEmail()
  email: string;
}

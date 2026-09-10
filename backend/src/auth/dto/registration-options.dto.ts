import { IsEmail } from 'class-validator';

export class RegistrationOptionsDto {
  @IsEmail()
  email: string;
}

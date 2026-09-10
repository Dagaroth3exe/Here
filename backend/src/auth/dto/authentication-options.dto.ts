import { IsEmail } from 'class-validator';

export class AuthenticationOptionsDto {
  @IsEmail()
  email: string;
}

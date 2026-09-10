import { IsEmail, IsString, Length } from 'class-validator';

export class TotpConfirmDto {
  @IsEmail()
  email: string;

  @IsString()
  @Length(6, 6)
  code: string;
}

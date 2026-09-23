import { IsString } from 'class-validator';

export class PasswordLoginDto {
  @IsString()
  name: string;

  @IsString()
  password: string;
}

import { IsString, Matches, MaxLength, MinLength } from 'class-validator';

export class PasswordSignupDto {
  @IsString()
  @MinLength(2)
  @MaxLength(40)
  @Matches(/^[a-zA-Z0-9 _.-]+$/, {
    message: 'Name can only contain letters, numbers, spaces, and _ . -',
  })
  name: string;

  @IsString()
  @MinLength(8)
  @MaxLength(72)
  password: string;
}

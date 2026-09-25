import { IsLatitude, IsLongitude, IsNotEmpty, IsOptional, IsString, MaxLength } from 'class-validator';

export class AskDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(500)
  question: string;

  /** The asker's position, so "nearby" questions search the right area. */
  @IsOptional()
  @IsLatitude()
  lat?: number;

  @IsOptional()
  @IsLongitude()
  lng?: number;
}

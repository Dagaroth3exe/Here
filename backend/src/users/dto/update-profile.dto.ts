import { ArrayMaxSize, IsArray, IsIn, IsOptional, IsString, MaxLength } from 'class-validator';
import { REACHABILITY_CATEGORIES } from '../reachability-categories.js';

export class UpdateProfileDto {
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(REACHABILITY_CATEGORIES.length)
  @IsIn(REACHABILITY_CATEGORIES, { each: true })
  categories?: string[];

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(10)
  @IsString({ each: true })
  @MaxLength(30, { each: true })
  interests?: string[];
}

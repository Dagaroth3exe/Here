import { Type } from 'class-transformer';
import { IsBoolean, IsLatitude, IsLongitude } from 'class-validator';

export class AreaQueryDto {
  @Type(() => Number)
  @IsLatitude()
  lat: number;

  @Type(() => Number)
  @IsLongitude()
  lng: number;
}

export class AreaPreferenceDto {
  @IsBoolean()
  notices: boolean;
}

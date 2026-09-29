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

/** The map's visible box. */
export class AreaBoundsDto {
  @Type(() => Number)
  @IsLatitude()
  south: number;

  @Type(() => Number)
  @IsLongitude()
  west: number;

  @Type(() => Number)
  @IsLatitude()
  north: number;

  @Type(() => Number)
  @IsLongitude()
  east: number;
}

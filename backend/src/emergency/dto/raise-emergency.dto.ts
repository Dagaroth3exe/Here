import { IsBoolean, IsIn, IsLatitude, IsLongitude, IsOptional, IsString, MaxLength } from 'class-validator';

export const EMERGENCY_REASONS = ['harassment', 'assault', 'followed', 'medical', 'other'] as const;
export type EmergencyReason = (typeof EMERGENCY_REASONS)[number];

export class RaiseEmergencyDto {
  @IsLatitude()
  lat: number;

  @IsLongitude()
  lng: number;

  @IsOptional()
  @IsIn(EMERGENCY_REASONS)
  reason?: EmergencyReason;

  @IsOptional()
  @IsString()
  @MaxLength(280)
  message?: string;
}

export class EmergencyLocationDto {
  @IsLatitude()
  lat: number;

  @IsLongitude()
  lng: number;
}

export class ResolveEmergencyDto {
  /** The sender ending it says it was never real (pressed by mistake, a test…). */
  @IsOptional()
  @IsBoolean()
  falseAlarm?: boolean;
}

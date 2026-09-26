import { IsOptional, IsString, Matches, MaxLength } from 'class-validator';

export class EndpointDto {
  @IsString()
  @MaxLength(500)
  endpoint: string;

  /** Web Push keys from the phone's registration (base64url), for encryption. */
  @IsOptional()
  @Matches(/^[A-Za-z0-9_-]{80,100}$/)
  p256dh?: string;

  @IsOptional()
  @Matches(/^[A-Za-z0-9_-]{16,32}$/)
  auth?: string;
}

export class RemoveEndpointDto {
  @IsString()
  @MaxLength(500)
  endpoint: string;
}

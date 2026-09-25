import { IsNotEmpty, IsString, IsUUID, MaxLength } from 'class-validator';

export const MAX_MESSAGE_LENGTH = 2000;

export class SendMessageDto {
  @IsUUID()
  targetId: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(MAX_MESSAGE_LENGTH)
  body: string;
}

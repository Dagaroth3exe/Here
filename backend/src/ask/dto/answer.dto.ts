import { IsNotEmpty, IsString, MaxLength } from 'class-validator';
import { MAX_ANSWER_LENGTH } from '../ask-community.service.js';

export class AnswerDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(MAX_ANSWER_LENGTH)
  body: string;
}

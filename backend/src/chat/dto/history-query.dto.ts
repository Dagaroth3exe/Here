import { IsISO8601, IsOptional } from 'class-validator';

export class HistoryQueryDto {
  /** Only messages older than this — for loading earlier pages. */
  @IsOptional()
  @IsISO8601()
  before?: string;
}

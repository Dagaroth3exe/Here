import { IsIn, IsOptional, IsString, IsUUID, MaxLength } from 'class-validator';
import { REPORT_REASONS, REPORT_TARGETS, type ReportReason, type ReportTarget } from '../report.entity.js';

export class ReportDto {
  @IsIn(REPORT_TARGETS)
  targetType: ReportTarget;

  @IsUUID()
  targetId: string;

  @IsIn(REPORT_REASONS)
  reason: ReportReason;

  @IsOptional()
  @IsString()
  @MaxLength(1000)
  details?: string;
}

import { Column, CreateDateColumn, Entity, Index, PrimaryGeneratedColumn } from 'typeorm';

export const REPORT_TARGETS = ['user', 'message', 'ask_question', 'ask_answer'] as const;
export type ReportTarget = (typeof REPORT_TARGETS)[number];

export const REPORT_REASONS = ['spam', 'harassment', 'inappropriate', 'scam', 'unsafe', 'other'] as const;
export type ReportReason = (typeof REPORT_REASONS)[number];

/** Something a user flagged for review. There's no review UI yet — rows wait here. */
@Entity('reports')
export class Report {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'reporter_id' })
  @Index()
  reporterId: string;

  @Column({ name: 'target_type', type: 'text' })
  targetType: ReportTarget;

  @Column({ name: 'target_id' })
  targetId: string;

  @Column({ type: 'text' })
  reason: ReportReason;

  @Column({ type: 'text', default: '' })
  details: string;

  @Column({ type: 'text', default: 'open' })
  @Index()
  status: 'open' | 'reviewed';

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;
}

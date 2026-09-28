import { Column, CreateDateColumn, Entity, Index, PrimaryGeneratedColumn } from 'typeorm';

/**
 * Someone raised the alarm: they need immediate help. Kept (not just relayed)
 * so the right people can be told when it's over, a recipient who taps the
 * push later can still open it, and repeat alarms can be rate-limited.
 */
@Entity('emergencies')
export class Emergency {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'user_id' })
  @Index()
  userId: string;

  /** Precise, unlike presence locations — finding the person is the point. */
  @Column({ type: 'double precision' })
  lat: number;

  @Column({ type: 'double precision' })
  lng: number;

  @Column({ type: 'text', nullable: true })
  reason: string | null;

  @Column({ type: 'text', nullable: true })
  message: string | null;

  /** Who was alerted — they're the ones told about updates and the all-clear. */
  @Column({ name: 'recipient_ids', type: 'uuid', array: true, default: () => "'{}'" })
  recipientIds: string[];

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;

  @Column({ name: 'resolved_at', type: 'timestamptz', nullable: true })
  resolvedAt: Date | null;

  /** People alerted who said it was a false alarm — two of them make it one. */
  @Column({ name: 'flagged_by', type: 'uuid', array: true, default: () => "'{}'" })
  flaggedBy: string[];

  /**
   * When this became a false alarm (sender said so, or enough flags) — a
   * strike against the sender's use of SOS. Null for a genuine alarm.
   */
  @Column({ name: 'false_alarm_at', type: 'timestamptz', nullable: true })
  @Index()
  falseAlarmAt: Date | null;
}

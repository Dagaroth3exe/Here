import { Column, CreateDateColumn, Entity, Index, PrimaryColumn } from 'typeorm';

/** A phone's UnifiedPush endpoint — where to POST notifications for [userId]. */
@Entity('push_endpoints')
export class PushEndpoint {
  @PrimaryColumn({ type: 'text' })
  endpoint: string;

  @Column({ name: 'user_id' })
  @Index()
  userId: string;

  /** The phone's Web Push keys (base64url) — notifications are encrypted to them. */
  @Column({ type: 'text', nullable: true })
  p256dh: string | null;

  @Column({ type: 'text', nullable: true })
  auth: string | null;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;
}

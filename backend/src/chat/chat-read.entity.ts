import { Column, Entity, PrimaryColumn } from 'typeorm';

/** How far [userId] has read their conversation with [otherId] — drives unread counts and "Seen". */
@Entity('chat_reads')
export class ChatRead {
  @PrimaryColumn({ name: 'user_id' })
  userId: string;

  @PrimaryColumn({ name: 'other_id' })
  otherId: string;

  @Column({ name: 'last_read_at', type: 'timestamptz' })
  lastReadAt: Date;
}

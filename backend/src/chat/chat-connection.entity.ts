import { Column, CreateDateColumn, Entity, Index, PrimaryColumn } from 'typeorm';

export type ConnectionStatus = 'pending' | 'accepted' | 'declined';

/**
 * Whether two people may chat. A first message is a chat request
 * ([requesterId] → the other); the recipient accepts (or just replies) or
 * declines. One row per pair, keyed with the smaller id first.
 */
@Entity('chat_connections')
export class ChatConnection {
  @PrimaryColumn({ name: 'user_a' })
  userA: string;

  @PrimaryColumn({ name: 'user_b' })
  @Index()
  userB: string;

  @Column({ name: 'requester_id' })
  requesterId: string;

  @Column({ type: 'text' })
  status: ConnectionStatus;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;

  @Column({ name: 'responded_at', type: 'timestamptz', nullable: true })
  respondedAt: Date | null;
}

/** The (userA, userB) key for a pair, whichever way round it's given. */
export function pairKey(x: string, y: string): { userA: string; userB: string } {
  return x < y ? { userA: x, userB: y } : { userA: y, userB: x };
}

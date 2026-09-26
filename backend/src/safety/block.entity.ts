import { CreateDateColumn, Entity, Index, PrimaryColumn } from 'typeorm';

/**
 * [blockerId] blocked [blockedId]. Works both ways once it exists: neither can
 * message or send chat requests to the other, and each is hidden from the
 * other's Discover list and map.
 */
@Entity('blocks')
export class Block {
  @PrimaryColumn({ name: 'blocker_id' })
  blockerId: string;

  @PrimaryColumn({ name: 'blocked_id' })
  @Index()
  blockedId: string;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;
}

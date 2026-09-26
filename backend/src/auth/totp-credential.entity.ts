import {
  Column,
  CreateDateColumn,
  Entity,
  JoinColumn,
  OneToOne,
  PrimaryGeneratedColumn,
  type Relation,
} from 'typeorm';
import { User } from '../users/user.entity.js';

@Entity('totp_credentials')
export class TotpCredential {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @OneToOne(() => User, (user) => user.totpCredential, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user: Relation<User>;

  @Column({ name: 'user_id', unique: true })
  userId: string;

  @Column({ name: 'secret_encrypted', type: 'text' })
  secretEncrypted: string;

  @Column({ default: false })
  confirmed: boolean;

  /**
   * The TOTP time-step consumed by the last successful verification.
   * Rejecting any code at or before this step stops the same code (or an
   * older one) being replayed within its validity window.
   */
  @Column({ name: 'last_used_step', type: 'bigint', nullable: true })
  lastUsedStep: number | null;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;
}

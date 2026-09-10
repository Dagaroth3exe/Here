import {
  Column,
  CreateDateColumn,
  Entity,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
  type Relation,
} from 'typeorm';
import { User } from '../users/user.entity.js';

@Entity('webauthn_credentials')
export class WebauthnCredential {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @ManyToOne(() => User, (user) => user.credentials, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user: Relation<User>;

  @Column({ name: 'user_id' })
  userId: string;

  @Column({ name: 'credential_id', unique: true })
  credentialId: string;

  @Column({ name: 'public_key', type: 'text' })
  publicKey: string;

  @Column({ type: 'bigint' })
  counter: number;

  @Column({ name: 'transports', type: 'simple-array', nullable: true })
  transports: string[] | null;

  @Column({ name: 'device_type' })
  deviceType: string;

  @Column({ name: 'backed_up' })
  backedUp: boolean;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;
}

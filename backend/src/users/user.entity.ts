import {
  Column,
  CreateDateColumn,
  Entity,
  OneToMany,
  OneToOne,
  PrimaryGeneratedColumn,
  type Relation,
} from 'typeorm';
import { TotpCredential } from '../auth/totp-credential.entity.js';
import { WebauthnCredential } from '../auth/webauthn-credential.entity.js';

@Entity('users')
export class User {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'varchar', unique: true, nullable: true })
  email: string | null;

  @Column({ type: 'varchar', unique: true, nullable: true })
  username: string | null;

  @Column({ name: 'password_hash', type: 'varchar', nullable: true })
  passwordHash: string | null;

  @Column({ name: 'display_name', type: 'varchar', nullable: true })
  displayName: string | null;

  @OneToMany(() => WebauthnCredential, (credential) => credential.user)
  credentials: Relation<WebauthnCredential>[];

  @OneToOne(() => TotpCredential, (totp) => totp.user)
  totpCredential: Relation<TotpCredential> | null;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;
}

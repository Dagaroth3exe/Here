import { Column, CreateDateColumn, Entity, Index, PrimaryGeneratedColumn } from 'typeorm';
import type { Place } from './web-sources.js';

/**
 * A question asked on Ask HERE, kept so later askers can find it (by meaning,
 * via [embedding]) and HERE members can answer it. Shown anonymously: only
 * the coarse area is public, never [askerId].
 */
@Entity('ask_questions')
export class AskQuestion {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  /** Only used to let the asker delete it — never sent to other users. */
  @Column({ name: 'asker_id' })
  @Index()
  askerId: string;

  @Column({ type: 'text' })
  question: string;

  /** nomic-embed-text vector of the question, for similarity search. */
  @Column({ type: 'real', array: true })
  embedding: number[];

  /** Rounded to 2 decimals (~1 km) — enough for "nearby", not a home address. */
  @Column({ type: 'double precision', nullable: true })
  lat: number | null;

  @Column({ type: 'double precision', nullable: true })
  lng: number | null;

  /** "Sector 125, Noida". */
  @Column({ type: 'text', nullable: true })
  area: string | null;

  /** What Ask HERE showed at the time, so the question page can show it again. */
  @Column({ type: 'text' })
  summary: string;

  @Column({ type: 'jsonb', default: () => "'[]'" })
  replies: unknown[];

  @Column({ type: 'jsonb', nullable: true })
  places: { places: Place[]; radiusM: number; near: string | null } | null;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  @Index()
  createdAt: Date;
}

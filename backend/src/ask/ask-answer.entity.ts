import { Column, CreateDateColumn, Entity, Index, PrimaryGeneratedColumn } from 'typeorm';

/** A HERE member's answer to a saved question — the community part. */
@Entity('ask_answers')
export class AskAnswer {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'question_id' })
  @Index()
  questionId: string;

  @Column({ name: 'author_id' })
  authorId: string;

  @Column({ type: 'text' })
  body: string;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;
}

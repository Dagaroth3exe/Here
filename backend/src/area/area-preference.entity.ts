import { Column, Entity, PrimaryColumn } from 'typeorm';

/** Whether someone wants area notices. No row means the default: on. */
@Entity('area_preferences')
export class AreaPreference {
  @PrimaryColumn({ name: 'user_id', type: 'uuid' })
  userId: string;

  @Column({ default: true })
  notices: boolean;
}

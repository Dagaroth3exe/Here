import { MigrationInterface, QueryRunner } from 'typeorm';

export class Initial1790948534225 implements MigrationInterface {
  name = 'Initial1790948534225';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`CREATE EXTENSION IF NOT EXISTS "uuid-ossp"`);
    await queryRunner.query(
      `CREATE TABLE "area_preferences" ("user_id" uuid NOT NULL, "notices" boolean NOT NULL DEFAULT true, CONSTRAINT "PK_1dd6d6ad3cb13c460692b1dc6d5" PRIMARY KEY ("user_id"))`,
    );
    await queryRunner.query(
      `CREATE TABLE "ask_answers" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "question_id" character varying NOT NULL, "author_id" character varying NOT NULL, "body" text NOT NULL, "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(), CONSTRAINT "PK_e33fb460f778d0c86d3913c5e7a" PRIMARY KEY ("id"))`,
    );
    await queryRunner.query(
      `CREATE INDEX "IDX_602539fd89522888a3a3d62993" ON "ask_answers"  ("question_id") `,
    );
    await queryRunner.query(
      `CREATE TABLE "ask_questions" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "asker_id" character varying NOT NULL, "question" text NOT NULL, "embedding" real array NOT NULL, "lat" double precision, "lng" double precision, "area" text, "summary" text NOT NULL, "replies" jsonb NOT NULL DEFAULT '[]', "web_answer" text NOT NULL DEFAULT '', "web_sources" jsonb NOT NULL DEFAULT '[]', "places" jsonb, "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(), CONSTRAINT "PK_0cde64cdd81f281bded26c1a786" PRIMARY KEY ("id"))`,
    );
    await queryRunner.query(
      `CREATE INDEX "IDX_2d2e29accd148a61d459414009" ON "ask_questions"  ("asker_id") `,
    );
    await queryRunner.query(
      `CREATE INDEX "IDX_545a84eeed1d7bdfe25fefbf37" ON "ask_questions"  ("created_at") `,
    );
    await queryRunner.query(
      `CREATE TABLE "webauthn_credentials" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "user_id" uuid NOT NULL, "credential_id" character varying NOT NULL, "public_key" text NOT NULL, "counter" bigint NOT NULL, "transports" text, "device_type" character varying NOT NULL, "backed_up" boolean NOT NULL, "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(), CONSTRAINT "UQ_8292f27b760a80388601db2d426" UNIQUE ("credential_id"), CONSTRAINT "PK_f5a100358f652926a5abae5e431" PRIMARY KEY ("id"))`,
    );
    await queryRunner.query(
      `CREATE TABLE "users" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "email" character varying, "username" character varying, "password_hash" character varying, "display_name" character varying, "phone" character varying, "google_id" character varying, "apple_id" character varying, "categories" text array NOT NULL DEFAULT '{}', "interests" text array NOT NULL DEFAULT '{}', "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(), CONSTRAINT "UQ_97672ac88f789774dd47f7c8be3" UNIQUE ("email"), CONSTRAINT "UQ_fe0bb3f6520ee0469504521e710" UNIQUE ("username"), CONSTRAINT "UQ_a000cca60bcf04454e727699490" UNIQUE ("phone"), CONSTRAINT "UQ_0bd5012aeb82628e07f6a1be53b" UNIQUE ("google_id"), CONSTRAINT "UQ_222297ce9ce93ae516d1e82b07c" UNIQUE ("apple_id"), CONSTRAINT "PK_a3ffb1c0c8416b9fc6f907b7433" PRIMARY KEY ("id"))`,
    );
    await queryRunner.query(
      `CREATE TABLE "totp_credentials" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "user_id" uuid NOT NULL, "secret_encrypted" text NOT NULL, "confirmed" boolean NOT NULL DEFAULT false, "last_used_step" bigint, "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(), CONSTRAINT "UQ_e7500eeafa3a0dcb09090965589" UNIQUE ("user_id"), CONSTRAINT "REL_e7500eeafa3a0dcb0909096558" UNIQUE ("user_id"), CONSTRAINT "PK_48831fcc514f614444afa41742e" PRIMARY KEY ("id"))`,
    );
    await queryRunner.query(
      `CREATE TABLE "messages" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "sender_id" character varying NOT NULL, "recipient_id" character varying NOT NULL, "body" text NOT NULL, "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(), CONSTRAINT "PK_18325f38ae6de43878487eff986" PRIMARY KEY ("id"))`,
    );
    await queryRunner.query(
      `CREATE INDEX "IDX_22133395bd13b970ccd0c34ab2" ON "messages"  ("sender_id") `,
    );
    await queryRunner.query(
      `CREATE INDEX "IDX_566c3d68184e83d4307b86f85a" ON "messages"  ("recipient_id") `,
    );
    await queryRunner.query(
      `CREATE TABLE "chat_connections" ("user_a" character varying NOT NULL, "user_b" character varying NOT NULL, "requester_id" character varying NOT NULL, "status" text NOT NULL, "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(), "responded_at" TIMESTAMP WITH TIME ZONE, CONSTRAINT "PK_57defd0ddfe04fe4b0d06c31f53" PRIMARY KEY ("user_a", "user_b"))`,
    );
    await queryRunner.query(
      `CREATE INDEX "IDX_3924749ee0fe39f18302dd7362" ON "chat_connections"  ("user_b") `,
    );
    await queryRunner.query(
      `CREATE TABLE "chat_reads" ("user_id" character varying NOT NULL, "other_id" character varying NOT NULL, "last_read_at" TIMESTAMP WITH TIME ZONE NOT NULL, CONSTRAINT "PK_ea48723917faa3249998a846ecc" PRIMARY KEY ("user_id", "other_id"))`,
    );
    await queryRunner.query(
      `CREATE TABLE "emergencies" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "user_id" character varying NOT NULL, "lat" double precision NOT NULL, "lng" double precision NOT NULL, "reason" text, "message" text, "recipient_ids" uuid array NOT NULL DEFAULT '{}', "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(), "resolved_at" TIMESTAMP WITH TIME ZONE, "flagged_by" uuid array NOT NULL DEFAULT '{}', "false_alarm_at" TIMESTAMP WITH TIME ZONE, CONSTRAINT "PK_7851897a3b7f700ac8702124aa8" PRIMARY KEY ("id"))`,
    );
    await queryRunner.query(
      `CREATE INDEX "IDX_939604f954fb54ff02c8faff2c" ON "emergencies"  ("user_id") `,
    );
    await queryRunner.query(
      `CREATE INDEX "IDX_46c58ebe975744c6798ca0a4cd" ON "emergencies"  ("false_alarm_at") `,
    );
    await queryRunner.query(
      `CREATE TABLE "push_endpoints" ("endpoint" text NOT NULL, "user_id" character varying NOT NULL, "p256dh" text, "auth" text, "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(), CONSTRAINT "PK_36a31b96ec2008fd5cd88b71270" PRIMARY KEY ("endpoint"))`,
    );
    await queryRunner.query(
      `CREATE INDEX "IDX_dd3ad1ab2890ff11c30b3aa21d" ON "push_endpoints"  ("user_id") `,
    );
    await queryRunner.query(
      `CREATE TABLE "blocks" ("blocker_id" character varying NOT NULL, "blocked_id" character varying NOT NULL, "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(), CONSTRAINT "PK_806f6a5d38d031cdd868fd5e37e" PRIMARY KEY ("blocker_id", "blocked_id"))`,
    );
    await queryRunner.query(
      `CREATE INDEX "IDX_8aa6c887bed61ad10829450f2f" ON "blocks"  ("blocked_id") `,
    );
    await queryRunner.query(
      `CREATE TABLE "reports" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "reporter_id" character varying NOT NULL, "target_type" text NOT NULL, "target_id" character varying NOT NULL, "reason" text NOT NULL, "details" text NOT NULL DEFAULT '', "status" text NOT NULL DEFAULT 'open', "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(), CONSTRAINT "PK_d9013193989303580053c0b5ef6" PRIMARY KEY ("id"))`,
    );
    await queryRunner.query(
      `CREATE INDEX "IDX_9459b9bf907a3807ef7143d2ea" ON "reports"  ("reporter_id") `,
    );
    await queryRunner.query(
      `CREATE INDEX "IDX_dab4d78b3be05c1ca4a626f57f" ON "reports"  ("status") `,
    );
    await queryRunner.query(
      `ALTER TABLE "webauthn_credentials" ADD CONSTRAINT "FK_cf9dd4c89545f22418bfcec368e" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION`,
    );
    await queryRunner.query(
      `ALTER TABLE "totp_credentials" ADD CONSTRAINT "FK_e7500eeafa3a0dcb09090965589" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "totp_credentials" DROP CONSTRAINT "FK_e7500eeafa3a0dcb09090965589"`,
    );
    await queryRunner.query(
      `ALTER TABLE "webauthn_credentials" DROP CONSTRAINT "FK_cf9dd4c89545f22418bfcec368e"`,
    );
    await queryRunner.query(
      `DROP INDEX "public"."IDX_dab4d78b3be05c1ca4a626f57f"`,
    );
    await queryRunner.query(
      `DROP INDEX "public"."IDX_9459b9bf907a3807ef7143d2ea"`,
    );
    await queryRunner.query(`DROP TABLE "reports"`);
    await queryRunner.query(
      `DROP INDEX "public"."IDX_8aa6c887bed61ad10829450f2f"`,
    );
    await queryRunner.query(`DROP TABLE "blocks"`);
    await queryRunner.query(
      `DROP INDEX "public"."IDX_dd3ad1ab2890ff11c30b3aa21d"`,
    );
    await queryRunner.query(`DROP TABLE "push_endpoints"`);
    await queryRunner.query(
      `DROP INDEX "public"."IDX_46c58ebe975744c6798ca0a4cd"`,
    );
    await queryRunner.query(
      `DROP INDEX "public"."IDX_939604f954fb54ff02c8faff2c"`,
    );
    await queryRunner.query(`DROP TABLE "emergencies"`);
    await queryRunner.query(`DROP TABLE "chat_reads"`);
    await queryRunner.query(
      `DROP INDEX "public"."IDX_3924749ee0fe39f18302dd7362"`,
    );
    await queryRunner.query(`DROP TABLE "chat_connections"`);
    await queryRunner.query(
      `DROP INDEX "public"."IDX_566c3d68184e83d4307b86f85a"`,
    );
    await queryRunner.query(
      `DROP INDEX "public"."IDX_22133395bd13b970ccd0c34ab2"`,
    );
    await queryRunner.query(`DROP TABLE "messages"`);
    await queryRunner.query(`DROP TABLE "totp_credentials"`);
    await queryRunner.query(`DROP TABLE "users"`);
    await queryRunner.query(`DROP TABLE "webauthn_credentials"`);
    await queryRunner.query(
      `DROP INDEX "public"."IDX_545a84eeed1d7bdfe25fefbf37"`,
    );
    await queryRunner.query(
      `DROP INDEX "public"."IDX_2d2e29accd148a61d459414009"`,
    );
    await queryRunner.query(`DROP TABLE "ask_questions"`);
    await queryRunner.query(
      `DROP INDEX "public"."IDX_602539fd89522888a3a3d62993"`,
    );
    await queryRunner.query(`DROP TABLE "ask_answers"`);
    await queryRunner.query(`DROP TABLE "area_preferences"`);
  }
}

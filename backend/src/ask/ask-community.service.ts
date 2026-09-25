import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Between, In, IsNull, Repository, type FindOptionsWhere } from 'typeorm';
import { publicName } from '../users/public-name.js';
import { UsersService } from '../users/users.service.js';
import { AskAnswer } from './ask-answer.entity.js';
import { AskQuestion } from './ask-question.entity.js';
import { cosine } from './ranking.js';

/** Paraphrases score ~0.77–0.91 with nomic-embed-text; unrelated questions ≤ ~0.55. */
const SIMILAR_THRESHOLD = 0.75;
/** "Nearby" for community questions: ~15 km box around the asker. */
const NEARBY_DEGREES = 0.15;
/** How many recent questions are compared by meaning (newest first). */
const CANDIDATES = 2000;
export const MAX_ANSWER_LENGTH = 2000;

type Location = { lat: number; lng: number } | null;

/** A saved question as other people see it — anonymous, area only. */
export interface PastQuestion {
  id: string;
  question: string;
  area: string | null;
  createdAt: string;
  answerCount: number;
}

export interface CommunityAnswer {
  id: string;
  author: string;
  body: string;
  createdAt: string;
  mine: boolean;
}

/**
 * The community side of Ask HERE: every answered question is kept, later
 * askers see similar ones from nearby, and HERE members answer each other.
 */
@Injectable()
export class AskCommunityService {
  constructor(
    @InjectRepository(AskQuestion) private readonly questions: Repository<AskQuestion>,
    @InjectRepository(AskAnswer) private readonly answers: Repository<AskAnswer>,
    private readonly usersService: UsersService,
  ) {}

  async save(input: {
    askerId: string;
    question: string;
    embedding: number[];
    location: Location;
    area: string | null;
    summary: string;
    replies: unknown[];
    places: AskQuestion['places'];
  }): Promise<string> {
    const round = (value: number) => Math.round(value * 100) / 100;
    const saved = await this.questions.save(
      this.questions.create({
        askerId: input.askerId,
        question: input.question,
        embedding: input.embedding,
        lat: input.location ? round(input.location.lat) : null,
        lng: input.location ? round(input.location.lng) : null,
        area: input.area,
        summary: input.summary,
        replies: input.replies,
        places: input.places,
      }),
    );
    return saved.id;
  }

  /** Earlier questions from around here that mean nearly the same thing, closest first. */
  async similar(embedding: number[], location: Location, limit = 5): Promise<PastQuestion[]> {
    const candidates = await this.questions.find({
      where: this.nearby(location),
      select: { id: true, question: true, area: true, createdAt: true, embedding: true },
      order: { createdAt: 'DESC' },
      take: CANDIDATES,
    });
    const matches = candidates
      .map((q) => ({ q, similarity: cosine(embedding, q.embedding) }))
      .filter((m) => m.similarity >= SIMILAR_THRESHOLD)
      .sort((a, b) => b.similarity - a.similarity)
      .slice(0, limit)
      .map((m) => m.q);
    return this.withAnswerCounts(matches);
  }

  /** The newest questions asked around here — the community feed. */
  async recent(location: Location, limit = 20): Promise<PastQuestion[]> {
    const latest = await this.questions.find({
      where: this.nearby(location),
      select: { id: true, question: true, area: true, createdAt: true },
      order: { createdAt: 'DESC' },
      take: limit,
    });
    return this.withAnswerCounts(latest);
  }

  async detail(id: string, viewerId: string) {
    const question = await this.questions.findOne({ where: { id } });
    if (!question) throw new NotFoundException('Question not found');
    const answers = await this.answers.find({ where: { questionId: id }, order: { createdAt: 'ASC' } });
    const authors = await Promise.all([...new Set(answers.map((a) => a.authorId))].map((a) => this.usersService.findById(a)));
    const names = new Map(authors.filter((u) => u !== null).map((u) => [u.id, publicName(u)]));
    return {
      id: question.id,
      question: question.question,
      area: question.area,
      createdAt: question.createdAt.toISOString(),
      mine: question.askerId === viewerId,
      summary: question.summary,
      replies: question.replies,
      places: question.places,
      answers: answers.map(
        (a): CommunityAnswer => ({
          id: a.id,
          author: names.get(a.authorId) ?? 'Someone',
          body: a.body,
          createdAt: a.createdAt.toISOString(),
          mine: a.authorId === viewerId,
        }),
      ),
    };
  }

  async answer(questionId: string, authorId: string, rawBody: string): Promise<CommunityAnswer> {
    const body = rawBody.trim();
    if (!body) throw new BadRequestException('Answer is empty');
    if (body.length > MAX_ANSWER_LENGTH) throw new BadRequestException('Answer is too long');
    if (!(await this.questions.exists({ where: { id: questionId } }))) throw new NotFoundException('Question not found');

    const [saved, author] = await Promise.all([
      this.answers.save(this.answers.create({ questionId, authorId, body })),
      this.usersService.findById(authorId),
    ]);
    return {
      id: saved.id,
      author: author ? publicName(author) : 'Someone',
      body: saved.body,
      createdAt: saved.createdAt.toISOString(),
      mine: true,
    };
  }

  /** Only the asker can remove their question (and its answers go with it). */
  async remove(questionId: string, userId: string): Promise<void> {
    const question = await this.questions.findOne({ where: { id: questionId }, select: { id: true, askerId: true } });
    if (!question) throw new NotFoundException('Question not found');
    if (question.askerId !== userId) throw new ForbiddenException('Only the person who asked can delete this');
    await this.answers.delete({ questionId });
    await this.questions.delete({ id: questionId });
  }

  /** Questions within ~15 km, plus ones asked without a location. */
  private nearby(location: Location): FindOptionsWhere<AskQuestion>[] | undefined {
    if (!location) return undefined;
    return [
      {
        lat: Between(location.lat - NEARBY_DEGREES, location.lat + NEARBY_DEGREES),
        lng: Between(location.lng - NEARBY_DEGREES, location.lng + NEARBY_DEGREES),
      },
      { lat: IsNull() },
    ];
  }

  private async withAnswerCounts(questions: Pick<AskQuestion, 'id' | 'question' | 'area' | 'createdAt'>[]): Promise<PastQuestion[]> {
    if (questions.length === 0) return [];
    const counts: { questionId: string; count: string }[] = await this.answers
      .createQueryBuilder('a')
      .select('a.question_id', 'questionId')
      .addSelect('COUNT(*)', 'count')
      .where({ questionId: In(questions.map((q) => q.id)) })
      .groupBy('a.question_id')
      .getRawMany();
    const byQuestion = new Map(counts.map((c) => [c.questionId, Number(c.count)]));
    return questions.map((q) => ({
      id: q.id,
      question: q.question,
      area: q.area,
      createdAt: q.createdAt.toISOString(),
      answerCount: byQuestion.get(q.id) ?? 0,
    }));
  }
}

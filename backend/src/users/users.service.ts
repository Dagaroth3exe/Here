import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { ILike, Repository } from 'typeorm';
import type { UpdateProfileDto } from './dto/update-profile.dto.js';
import { User } from './user.entity.js';

export interface PublicProfile {
  id: string;
  username: string | null;
  categories: string[];
  interests: string[];
}

@Injectable()
export class UsersService {
  constructor(
    @InjectRepository(User)
    private readonly usersRepository: Repository<User>,
  ) {}

  findByEmail(email: string): Promise<User | null> {
    return this.usersRepository.findOne({
      where: { email },
      relations: { credentials: true, totpCredential: true },
    });
  }

  findById(id: string): Promise<User | null> {
    return this.usersRepository.findOne({
      where: { id },
      relations: { credentials: true, totpCredential: true },
    });
  }

  /**
   * Case-insensitive — "Rishabh" and "rishabh" are the same account. Without
   * this, a user who signs up as "Rishabh" but later types "rishabh" to log
   * in gets a false "incorrect name or password" (the lookup just misses).
   */
  findByUsername(username: string): Promise<User | null> {
    return this.usersRepository.findOne({ where: { username: ILike(username) } });
  }

  findByPhone(phone: string): Promise<User | null> {
    return this.usersRepository.findOne({ where: { phone } });
  }

  findByGoogleId(googleId: string): Promise<User | null> {
    return this.usersRepository.findOne({ where: { googleId } });
  }

  findByAppleId(appleId: string): Promise<User | null> {
    return this.usersRepository.findOne({ where: { appleId } });
  }

  /** Partial, case-insensitive username match for the "start a new chat"
   * search — lets you find someone even if they're not currently online. */
  async search(query: string, excludeUserId: string): Promise<{ id: string; username: string }[]> {
    const trimmed = query.trim();
    if (!trimmed) return [];

    const users = await this.usersRepository
      .createQueryBuilder('user')
      .where('user.id != :excludeUserId', { excludeUserId })
      .andWhere('user.username ILIKE :query', { query: `%${trimmed}%` })
      .orderBy('user.username', 'ASC')
      .limit(20)
      .getMany();

    return users
      .filter((u) => u.username)
      .map((u) => ({ id: u.id, username: u.username! }));
  }

  async getProfile(userId: string): Promise<PublicProfile> {
    const user = await this.usersRepository.findOne({ where: { id: userId } });
    if (!user) throw new NotFoundException('User not found');
    return this.toPublicProfile(user);
  }

  async updateProfile(userId: string, update: UpdateProfileDto): Promise<PublicProfile> {
    const user = await this.usersRepository.findOne({ where: { id: userId } });
    if (!user) throw new NotFoundException('User not found');
    if (update.categories !== undefined) user.categories = update.categories;
    if (update.interests !== undefined) user.interests = update.interests;
    await this.usersRepository.save(user);
    return this.toPublicProfile(user);
  }

  private toPublicProfile(user: User): PublicProfile {
    return {
      id: user.id,
      username: user.username,
      categories: user.categories,
      interests: user.interests,
    };
  }

  create(email: string): Promise<User> {
    const user = this.usersRepository.create({ email });
    return this.usersRepository.save(user);
  }

  createWithPassword(username: string, passwordHash: string): Promise<User> {
    const user = this.usersRepository.create({ username, passwordHash });
    return this.usersRepository.save(user);
  }

  createWithPhone(phone: string): Promise<User> {
    const user = this.usersRepository.create({ phone, displayName: phone });
    return this.usersRepository.save(user);
  }

  createWithSocial(input: {
    provider: 'google' | 'apple';
    subject: string;
    email: string | null;
    name: string | null;
  }): Promise<User> {
    const user = this.usersRepository.create({
      email: input.email,
      displayName: input.name,
      googleId: input.provider === 'google' ? input.subject : null,
      appleId: input.provider === 'apple' ? input.subject : null,
    });
    return this.usersRepository.save(user);
  }

  save(user: User): Promise<User> {
    return this.usersRepository.save(user);
  }
}

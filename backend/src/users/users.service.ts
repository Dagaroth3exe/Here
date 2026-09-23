import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { ILike, Repository } from 'typeorm';
import { User } from './user.entity.js';

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

  create(email: string): Promise<User> {
    const user = this.usersRepository.create({ email });
    return this.usersRepository.save(user);
  }

  createWithPassword(username: string, passwordHash: string): Promise<User> {
    const user = this.usersRepository.create({ username, passwordHash });
    return this.usersRepository.save(user);
  }
}

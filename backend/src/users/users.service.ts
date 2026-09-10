import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
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

  create(email: string): Promise<User> {
    const user = this.usersRepository.create({ email });
    return this.usersRepository.save(user);
  }
}

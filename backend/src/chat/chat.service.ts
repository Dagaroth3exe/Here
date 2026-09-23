import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { UsersService } from '../users/users.service.js';
import { Message } from './message.entity.js';

export interface ConversationSummary {
  userId: string;
  name: string;
  lastBody: string;
  lastAt: string;
}

@Injectable()
export class ChatService {
  constructor(
    @InjectRepository(Message) private readonly messages: Repository<Message>,
    private readonly usersService: UsersService,
  ) {}

  async saveMessage(senderId: string, recipientId: string, body: string): Promise<Message> {
    const message = this.messages.create({ senderId, recipientId, body });
    return this.messages.save(message);
  }

  history(userId: string, otherUserId: string): Promise<Message[]> {
    return this.messages.find({
      where: [
        { senderId: userId, recipientId: otherUserId },
        { senderId: otherUserId, recipientId: userId },
      ],
      order: { createdAt: 'ASC' },
    });
  }

  /** One row per other party, most recent message first. */
  async conversations(userId: string): Promise<ConversationSummary[]> {
    const rows = await this.messages
      .createQueryBuilder('m')
      .where('m.senderId = :userId OR m.recipientId = :userId', { userId })
      .orderBy('m.createdAt', 'DESC')
      .getMany();

    const lastByOtherParty = new Map<string, Message>();
    for (const row of rows) {
      const otherId = row.senderId === userId ? row.recipientId : row.senderId;
      if (!lastByOtherParty.has(otherId)) lastByOtherParty.set(otherId, row);
    }

    const summaries: ConversationSummary[] = [];
    for (const [otherId, lastMessage] of lastByOtherParty) {
      const other = await this.usersService.findById(otherId);
      summaries.push({
        userId: otherId,
        name: other?.username ?? other?.email ?? 'Someone',
        lastBody: lastMessage.body,
        lastAt: lastMessage.createdAt.toISOString(),
      });
    }
    return summaries;
  }
}

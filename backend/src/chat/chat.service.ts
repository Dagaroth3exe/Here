import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { publicName } from '../users/public-name.js';
import { UsersService } from '../users/users.service.js';
import { ChatEvents, type ChatMessagePayload } from './chat-events.js';
import { MAX_MESSAGE_LENGTH } from './dto/send-message.dto.js';
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
    private readonly events: ChatEvents,
  ) {}

  /**
   * The one way a message gets sent — over the WebSocket or plain HTTP — so
   * both paths validate the same way, and both parties get it live via
   * [ChatEvents] if they're connected (history covers them if not).
   */
  async send(senderId: string, targetId: string, rawBody: string): Promise<ChatMessagePayload> {
    const body = rawBody.trim();
    if (!body) throw new BadRequestException('Message is empty');
    if (body.length > MAX_MESSAGE_LENGTH) throw new BadRequestException('Message is too long');
    if (targetId === senderId) throw new BadRequestException("You can't message yourself");

    const [sender, target] = await Promise.all([
      this.usersService.findById(senderId),
      this.usersService.findById(targetId),
    ]);
    if (!sender || !target) throw new NotFoundException('User not found');

    const saved = await this.messages.save(this.messages.create({ senderId, recipientId: targetId, body }));
    const payload: ChatMessagePayload = {
      id: saved.id,
      fromId: senderId,
      fromName: publicName(sender),
      targetId,
      targetName: publicName(target),
      body: saved.body,
      createdAt: saved.createdAt.toISOString(),
    };
    this.events.emit(payload);
    return payload;
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
        name: other ? publicName(other) : 'Someone',
        lastBody: lastMessage.body,
        lastAt: lastMessage.createdAt.toISOString(),
      });
    }
    return summaries;
  }
}

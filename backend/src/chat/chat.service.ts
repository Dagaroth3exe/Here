import { BadRequestException, ConflictException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { LessThan, Repository } from 'typeorm';
import { UserEvents } from '../events/user-events.js';
import { SafetyService } from '../safety/safety.service.js';
import { publicName } from '../users/public-name.js';
import { UsersService } from '../users/users.service.js';
import { ChatConnection, pairKey, type ConnectionStatus } from './chat-connection.entity.js';
import { ChatRead } from './chat-read.entity.js';
import { decideSend } from './chat-rules.js';
import { MAX_MESSAGE_LENGTH } from './dto/send-message.dto.js';
import { Message } from './message.entity.js';

/** What both parties receive for every new message, however it was sent. */
export interface ChatMessagePayload {
  id: string;
  fromId: string;
  fromName: string;
  targetId: string;
  targetName: string;
  body: string;
  createdAt: string;
  /** 'pending' while it's a chat request the recipient hasn't accepted. */
  status: 'pending' | 'accepted';
  requesterId: string;
}

/**
 * How the viewer sees a conversation: 'incoming' is a request waiting for
 * them, 'outgoing' one they're waiting on, 'declined' their request that
 * was turned down, 'none' no contact yet (the first message will be a request).
 */
export type ConversationStatus = 'none' | 'accepted' | 'incoming' | 'outgoing' | 'declined';

export interface ConversationSummary {
  userId: string;
  name: string;
  lastBody: string;
  lastAt: string;
  lastFromMe: boolean;
  status: ConversationStatus;
  unreadCount: number;
}

const PAGE_SIZE = 50;

@Injectable()
export class ChatService {
  constructor(
    @InjectRepository(Message) private readonly messages: Repository<Message>,
    @InjectRepository(ChatConnection) private readonly connections: Repository<ChatConnection>,
    @InjectRepository(ChatRead) private readonly reads: Repository<ChatRead>,
    private readonly usersService: UsersService,
    private readonly safety: SafetyService,
    private readonly events: UserEvents,
  ) {}

  /**
   * The one way a message gets sent — over the WebSocket or plain HTTP — so
   * both paths apply the same rules: blocks, chat requests (first contact
   * needs accepting), and validation. Both parties get it live, and the
   * recipient a push notification.
   */
  async send(senderId: string, targetId: string, rawBody: string): Promise<ChatMessagePayload> {
    const body = rawBody.trim();
    if (!body) throw new BadRequestException('Message is empty');
    if (body.length > MAX_MESSAGE_LENGTH) throw new BadRequestException('Message is too long');
    if (targetId === senderId) throw new BadRequestException("You can't message yourself");
    if (await this.safety.isBlockedEitherWay(senderId, targetId)) {
      throw new ForbiddenException("You can't message this person");
    }

    const users = await this.usersService.findByIds([senderId, targetId]);
    const sender = users.get(senderId);
    const target = users.get(targetId);
    if (!sender || !target) throw new NotFoundException('User not found');

    const key = pairKey(senderId, targetId);
    const connection = await this.connections.findOne({ where: key });
    const decision = decideSend(connection, !connection && (await this.hasHistory(senderId, targetId)), senderId);

    let status: ConnectionStatus;
    let requesterId: string;
    switch (decision.action) {
      case 'refuse':
        throw decision.reason === 'awaiting'
          ? new ConflictException(`Wait for ${publicName(target)} to accept your chat request`)
          : new ForbiddenException(`${publicName(target)} declined your chat request`);
      case 'request':
        await this.connections.save(this.connections.create({ ...key, requesterId: senderId, status: 'pending' }));
        [status, requesterId] = ['pending', senderId];
        break;
      case 'grandfather':
        await this.connections.save(
          this.connections.create({ ...key, requesterId: senderId, status: 'accepted', respondedAt: new Date() }),
        );
        [status, requesterId] = ['accepted', senderId];
        break;
      case 'accept':
        await this.connections.update(key, { status: 'accepted', respondedAt: new Date() });
        this.announceResponse(connection!.requesterId, senderId, publicName(sender), 'accepted');
        [status, requesterId] = ['accepted', connection!.requesterId];
        break;
      case 'send':
        [status, requesterId] = ['accepted', connection!.requesterId];
        break;
    }

    const saved = await this.messages.save(this.messages.create({ senderId, recipientId: targetId, body }));
    const payload: ChatMessagePayload = {
      id: saved.id,
      fromId: senderId,
      fromName: publicName(sender),
      targetId,
      targetName: publicName(target),
      body: saved.body,
      createdAt: saved.createdAt.toISOString(),
      status: status === 'pending' ? 'pending' : 'accepted',
      requesterId,
    };
    const isRequest = decision.action === 'request';
    this.events.deliver({
      to: [senderId, targetId],
      event: 'chat:message',
      data: payload,
    });
    this.events.deliver({
      to: [targetId],
      event: 'chat:notify',
      data: null,
      push: {
        title: isRequest ? `${payload.fromName} sent you a chat request` : payload.fromName,
        body: body.length > 120 ? `${body.slice(0, 117)}…` : body,
        data: { kind: isRequest ? 'request' : 'message', userId: senderId, name: payload.fromName },
      },
    });
    return payload;
  }

  /**
   * A page of the conversation, oldest first: the latest [PAGE_SIZE], or the
   * ones before [before] when scrolling back. Also how far the other person
   * has read (for "Seen") and where the chat request stands.
   */
  async history(userId: string, otherId: string, before?: Date) {
    const where = (from: string, to: string) =>
      before ? { senderId: from, recipientId: to, createdAt: LessThan(before) } : { senderId: from, recipientId: to };
    const [page, connection, theirRead, hidden] = await Promise.all([
      this.messages.find({
        where: [where(userId, otherId), where(otherId, userId)],
        order: { createdAt: 'DESC' },
        take: PAGE_SIZE + 1,
      }),
      this.connections.findOne({ where: pairKey(userId, otherId) }),
      this.reads.findOne({ where: { userId: otherId, otherId: userId } }),
      this.safety.hiddenFrom(userId),
    ]);
    const hasMore = page.length > PAGE_SIZE;
    return {
      messages: page.slice(0, PAGE_SIZE).reverse(),
      hasMore,
      status: this.statusFor(userId, connection, page.length > 0),
      otherLastReadAt: theirRead?.lastReadAt.toISOString() ?? null,
      blocked: hidden.has(otherId),
    };
  }

  /**
   * One row per other person, most recent first, with unread counts and
   * request status. Blocked people (either way) are left out, as are
   * requests the viewer declined.
   */
  async conversations(userId: string): Promise<ConversationSummary[]> {
    const [rows, connections, reads, hidden] = await Promise.all([
      this.messages
        .createQueryBuilder('m')
        .where('m.senderId = :userId OR m.recipientId = :userId', { userId })
        .orderBy('m.createdAt', 'DESC')
        .getMany(),
      this.connections.find({ where: [{ userA: userId }, { userB: userId }] }),
      this.reads.find({ where: { userId } }),
      this.safety.hiddenFrom(userId),
    ]);
    const connectionWith = new Map(connections.map((c) => [c.userA === userId ? c.userB : c.userA, c]));
    const readUpTo = new Map(reads.map((r) => [r.otherId, r.lastReadAt.getTime()]));

    const byOther = new Map<string, { last: Message; unread: number }>();
    for (const row of rows) {
      const otherId = row.senderId === userId ? row.recipientId : row.senderId;
      if (hidden.has(otherId)) continue;
      const entry = byOther.get(otherId) ?? { last: row, unread: 0 };
      if (row.senderId === otherId && row.createdAt.getTime() > (readUpTo.get(otherId) ?? 0)) entry.unread++;
      byOther.set(otherId, entry);
    }

    const users = await this.usersService.findByIds([...byOther.keys()]);
    const summaries: ConversationSummary[] = [];
    for (const [otherId, { last, unread }] of byOther) {
      const connection = connectionWith.get(otherId) ?? null;
      // Declined by me: gone from my list (the requester still sees "declined").
      if (connection?.status === 'declined' && connection.requesterId !== userId) continue;
      const user = users.get(otherId);
      summaries.push({
        userId: otherId,
        name: user ? publicName(user) : 'Someone',
        lastBody: last.body,
        lastAt: last.createdAt.toISOString(),
        lastFromMe: last.senderId === userId,
        status: this.statusFor(userId, connection, true),
        unreadCount: unread,
      });
    }
    return summaries;
  }

  /** Total unread messages in accepted chats, and chat requests waiting for a reply — for the tab badge. */
  async unread(userId: string): Promise<{ messages: number; requests: number }> {
    const conversations = await this.conversations(userId);
    return {
      messages: conversations.filter((c) => c.status === 'accepted').reduce((n, c) => n + c.unreadCount, 0),
      requests: conversations.filter((c) => c.status === 'incoming').length,
    };
  }

  /** The viewer has read everything so far — clears unread and shows "Seen" to the other person. */
  async markRead(userId: string, otherId: string): Promise<void> {
    const lastReadAt = new Date();
    await this.reads.upsert({ userId, otherId, lastReadAt }, ['userId', 'otherId']);
    if (!(await this.safety.isBlockedEitherWay(userId, otherId))) {
      this.events.deliver({ to: [otherId], event: 'chat:read', data: { byId: userId, at: lastReadAt.toISOString() } });
    }
  }

  async respond(userId: string, requesterId: string, accept: boolean): Promise<void> {
    const key = pairKey(userId, requesterId);
    const connection = await this.connections.findOne({ where: key });
    if (!connection || connection.status !== 'pending' || connection.requesterId !== requesterId) {
      throw new NotFoundException('No chat request from this person');
    }
    const status = accept ? 'accepted' : 'declined';
    await this.connections.update(key, { status, respondedAt: new Date() });
    const me = await this.usersService.findById(userId);
    this.announceResponse(requesterId, userId, me ? publicName(me) : 'Someone', status);
  }

  /** Tells the requester their request was answered (live, and as a push when accepted). */
  private announceResponse(requesterId: string, responderId: string, responderName: string, status: 'accepted' | 'declined') {
    this.events.deliver({
      to: [requesterId],
      event: 'chat:request_update',
      data: { userId: responderId, status },
      push:
        status === 'accepted'
          ? {
              title: `${responderName} accepted your chat request`,
              body: 'You can chat now.',
              data: { kind: 'message', userId: responderId, name: responderName },
            }
          : undefined,
    });
  }

  private statusFor(userId: string, connection: ChatConnection | null, hasHistory: boolean): ConversationStatus {
    // Chats from before requests existed have no row: they're accepted.
    if (!connection) return hasHistory ? 'accepted' : 'none';
    if (connection.status === 'accepted') return 'accepted';
    const mine = connection.requesterId === userId;
    if (connection.status === 'pending') return mine ? 'outgoing' : 'incoming';
    return 'declined';
  }

  private hasHistory(a: string, b: string): Promise<boolean> {
    return this.messages.exists({
      where: [
        { senderId: a, recipientId: b },
        { senderId: b, recipientId: a },
      ],
    });
  }
}

import { Injectable } from '@nestjs/common';
import { Subject } from 'rxjs';

/** What both parties receive for every new message, however it was sent. */
export interface ChatMessagePayload {
  id: string;
  fromId: string;
  fromName: string;
  targetId: string;
  targetName: string;
  body: string;
  createdAt: string;
}

/**
 * Lets [ChatService] announce saved messages without depending on the
 * realtime gateway (which already depends on it) — the gateway subscribes and
 * pushes each one to whichever of the two parties are connected.
 */
@Injectable()
export class ChatEvents {
  private readonly subject = new Subject<ChatMessagePayload>();
  readonly messages$ = this.subject.asObservable();

  emit(message: ChatMessagePayload) {
    this.subject.next(message);
  }
}

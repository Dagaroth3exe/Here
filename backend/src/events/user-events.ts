import { Injectable } from '@nestjs/common';
import { Subject } from 'rxjs';

/** A phone notification for someone who may not have HERE open. */
export interface PushNotice {
  title: string;
  body: string;
  /** Tells the app what to open when the notification is tapped. */
  data: Record<string, string>;
}

/** Something that should reach specific users: live if connected, as a push notification if [push] is set. */
export interface UserDelivery {
  to: string[];
  event: string;
  data: unknown;
  push?: PushNotice;
}

/**
 * One bus for "tell these users X" — chat, chat requests, read receipts, Ask
 * HERE answers. Senders don't depend on how delivery happens: the realtime
 * gateway pushes to open sockets, the push service to phones.
 */
@Injectable()
export class UserEvents {
  private readonly subject = new Subject<UserDelivery>();
  readonly deliveries$ = this.subject.asObservable();

  deliver(delivery: UserDelivery) {
    this.subject.next(delivery);
  }
}

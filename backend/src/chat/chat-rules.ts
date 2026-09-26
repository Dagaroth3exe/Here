import type { ConnectionStatus } from './chat-connection.entity.js';

export type SendDecision =
  /** First contact: this message is a chat request the other person must accept. */
  | { action: 'request' }
  /** Pair chatted before requests existed — treat as already accepted. */
  | { action: 'grandfather' }
  /** The recipient of a request replied — that accepts it. */
  | { action: 'accept' }
  | { action: 'send' }
  | { action: 'refuse'; reason: 'awaiting' | 'declined' };

/**
 * Whether [senderId] may send to the other person, given their connection.
 * A request is one message: the requester can't add more until it's
 * accepted, and can't send again once declined. The recipient replying
 * counts as accepting, even after declining (they changed their mind).
 */
export function decideSend(
  connection: { status: ConnectionStatus; requesterId: string } | null,
  hasHistory: boolean,
  senderId: string,
): SendDecision {
  if (!connection) return hasHistory ? { action: 'grandfather' } : { action: 'request' };
  if (connection.status === 'accepted') return { action: 'send' };
  if (connection.requesterId !== senderId) return { action: 'accept' };
  return { action: 'refuse', reason: connection.status === 'pending' ? 'awaiting' : 'declined' };
}

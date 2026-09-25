/**
 * Real replies from community forums — what people who were in the same
 * situation actually said. Threads are found through SearXNG (site-filtered
 * searches); replies come from each forum's official API:
 * - Reddit: Data API with app-only OAuth (it blocks all logged-out access).
 *   Skipped when no credentials are configured.
 * - Stack Exchange: public API (content is CC BY-SA), no key needed.
 * Everything here is untrusted user content — data, never instructions.
 */

import { htmlToText } from './web-sources.js';

export type Platform = 'reddit' | 'stackexchange';

export interface Thread {
  platform: Platform;
  /** Reddit post id, or Stack Exchange question id. */
  id: string;
  /** Stack Exchange site api name ("travel", "expatriates", "stackoverflow"). */
  site?: string;
  title: string;
  url: string;
}

export interface Reply {
  platform: Platform;
  author: string;
  /** "r/noida", "Travel Stack Exchange". */
  community: string;
  text: string;
  /** Upvotes (Reddit) or votes (Stack Exchange). */
  score: number;
  createdAt: string;
  url: string;
  threadTitle: string;
}

const USER_AGENT_FALLBACK = 'server:here-app:0.1 (self-hosted HERE instance)';
const MIN_REPLY_CHARS = 40;
const MAX_REPLY_CHARS = 1200;

/** Recognises thread URLs from search results; anything else is ignored. */
export function parseThreadUrl(url: string, title: string): Thread | null {
  let parsed: URL;
  try {
    parsed = new URL(url);
  } catch {
    return null;
  }
  const host = parsed.hostname.replace(/^(www|old|new|np)\./, '');

  const reddit = host === 'reddit.com' ? /\/comments\/([a-z0-9]+)/i.exec(parsed.pathname) : null;
  if (reddit) {
    return { platform: 'reddit', id: reddit[1].toLowerCase(), title: cleanTitle(title), url: `https://www.reddit.com/comments/${reddit[1]}` };
  }

  const question = /^\/questions\/(\d+)/.exec(parsed.pathname);
  const site = question ? stackExchangeSite(host) : null;
  if (question && site) {
    return { platform: 'stackexchange', id: question[1], site, title: cleanTitle(title), url: `https://${host}/questions/${question[1]}` };
  }
  return null;
}

function stackExchangeSite(host: string): string | null {
  if (host.endsWith('.stackexchange.com')) {
    const name = host.slice(0, -'.stackexchange.com'.length);
    // meta.* sites discuss the site itself, not people's situations.
    return name.includes('meta') ? null : name;
  }
  const standalone: Record<string, string> = {
    'stackoverflow.com': 'stackoverflow',
    'superuser.com': 'superuser',
    'serverfault.com': 'serverfault',
    'askubuntu.com': 'askubuntu',
  };
  return standalone[host] ?? null;
}

/** "Need a room nearby 62 area : r/noida" → "Need a room nearby 62 area". */
function cleanTitle(title: string): string {
  return title.replace(/\s*[:|–-]\s*(r\/\w+|reddit|[\w ]+ stack exchange)\s*$/i, '').trim();
}

function trimText(text: string): string {
  const clean = text.replace(/\s+/g, ' ').trim();
  return clean.length > MAX_REPLY_CHARS ? `${clean.slice(0, MAX_REPLY_CHARS).replace(/\s\S*$/, '')}…` : clean;
}

// ---------------------------------------------------------------- Reddit ---

interface RedditCredentials {
  clientId: string;
  clientSecret: string;
  userAgent?: string;
}

interface RedditComment {
  kind: string;
  data: {
    author?: string;
    body?: string;
    score?: number;
    created_utc?: number;
    permalink?: string;
    stickied?: boolean;
    replies?: { data?: { children?: RedditComment[] } } | '';
  };
}

export class RedditClient {
  private token: { value: string; expiresAt: number } | null = null;

  constructor(private readonly credentials: RedditCredentials) {}

  private get userAgent() {
    return this.credentials.userAgent || USER_AGENT_FALLBACK;
  }

  /** App-only OAuth token, reused until shortly before it expires. */
  private async accessToken(): Promise<string> {
    if (this.token && Date.now() < this.token.expiresAt) return this.token.value;
    const basic = Buffer.from(`${this.credentials.clientId}:${this.credentials.clientSecret}`).toString('base64');
    const response = await fetch('https://www.reddit.com/api/v1/access_token', {
      method: 'POST',
      headers: { Authorization: `Basic ${basic}`, 'User-Agent': this.userAgent },
      body: new URLSearchParams({ grant_type: 'client_credentials' }),
      signal: AbortSignal.timeout(8_000),
    });
    if (!response.ok) throw new Error(`Reddit auth responded ${response.status}`);
    const data = (await response.json()) as { access_token: string; expires_in: number };
    this.token = { value: data.access_token, expiresAt: Date.now() + (data.expires_in - 60) * 1000 };
    return data.access_token;
  }

  async replies(thread: Thread): Promise<Reply[]> {
    const token = await this.accessToken();
    const response = await fetch(
      `https://oauth.reddit.com/comments/${thread.id}?${new URLSearchParams({ sort: 'top', limit: '60', depth: '2', raw_json: '1' })}`,
      {
        headers: { Authorization: `Bearer ${token}`, 'User-Agent': this.userAgent },
        signal: AbortSignal.timeout(8_000),
      },
    );
    if (!response.ok) throw new Error(`Reddit responded ${response.status}`);
    return parseRedditThread(await response.json(), thread);
  }
}

/** Top-level comments and their direct replies, minus deleted/bot/tiny ones. */
export function parseRedditThread(json: unknown, thread: Thread): Reply[] {
  const [postListing, commentListing] = json as [
    { data: { children: { data: { title?: string; subreddit_name_prefixed?: string } }[] } },
    { data: { children: RedditComment[] } },
  ];
  const post = postListing?.data?.children?.[0]?.data ?? {};
  const community = post.subreddit_name_prefixed ?? 'Reddit';
  const threadTitle = post.title ?? thread.title;

  const replies: Reply[] = [];
  const visit = (comments: RedditComment[] | undefined, depth: number) => {
    for (const comment of comments ?? []) {
      if (comment.kind !== 't1') continue;
      const c = comment.data;
      const body = c.body ?? '';
      const removed = body === '[deleted]' || body === '[removed]' || !c.author || c.author === '[deleted]';
      const bot = c.author === 'AutoModerator' || c.stickied;
      if (!removed && !bot && body.trim().length >= MIN_REPLY_CHARS) {
        replies.push({
          platform: 'reddit',
          author: `u/${c.author}`,
          community,
          text: trimText(body),
          score: c.score ?? 0,
          createdAt: new Date((c.created_utc ?? 0) * 1000).toISOString(),
          url: c.permalink ? `https://www.reddit.com${c.permalink}` : thread.url,
          threadTitle,
        });
      }
      if (depth < 1 && c.replies) visit(c.replies.data?.children, depth + 1);
    }
  };
  visit(commentListing?.data?.children, 0);
  return replies;
}

// -------------------------------------------------------- Stack Exchange ---

export async function stackExchangeReplies(thread: Thread, key?: string): Promise<Reply[]> {
  const params = new URLSearchParams({ site: thread.site!, filter: 'withbody', sort: 'votes', pagesize: '15' });
  if (key) params.set('key', key);
  const response = await fetch(`https://api.stackexchange.com/2.3/questions/${thread.id}/answers?${params}`, {
    signal: AbortSignal.timeout(8_000),
  });
  if (!response.ok) throw new Error(`Stack Exchange responded ${response.status}`);
  const data = (await response.json()) as {
    items?: { body: string; score: number; creation_date: number; answer_id: number; owner?: { display_name?: string } }[];
  };
  const community = `${thread.site!.replace(/^\w/, (c) => c.toUpperCase())} Stack Exchange`;
  return (data.items ?? [])
    .map((a) => ({
      platform: 'stackexchange' as const,
      author: htmlToText(a.owner?.display_name ?? 'Anonymous'),
      community,
      text: trimText(htmlToText(a.body)),
      score: a.score,
      createdAt: new Date(a.creation_date * 1000).toISOString(),
      url: `${thread.url}#${a.answer_id}`,
      threadTitle: thread.title,
    }))
    .filter((r) => r.text.length >= MIN_REPLY_CHARS);
}

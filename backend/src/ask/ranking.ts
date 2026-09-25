/** Relevance helpers for picking which community replies and web passages to use. */

const CHUNK_CHARS = 700;
const MIN_CHUNK_CHARS = 80;

/**
 * Sentence-aware ~700-char chunks of a web page, each starting with the
 * previous one's last sentence, so the relevant middle of a long page can be
 * found instead of its first few thousand characters (usually navigation).
 */
export function chunkText(text: string, maxChunks: number): string[] {
  const sentences = text
    .split(/(?<=[.!?])\s+/)
    // Scraped pages often have huge punctuation-free runs (menus, lists).
    .flatMap((s) => (s.length > CHUNK_CHARS ? (s.match(new RegExp(`.{1,${CHUNK_CHARS}}`, 'g')) ?? []) : [s]));

  const chunks: string[] = [];
  let current: string[] = [];
  let length = 0;
  for (const sentence of sentences) {
    if (length + sentence.length > CHUNK_CHARS && current.length > 0) {
      chunks.push(current.join(' '));
      if (chunks.length >= maxChunks) break;
      const overlap = current.at(-1)!;
      current = overlap.length < CHUNK_CHARS / 3 ? [overlap] : [];
      length = current.reduce((n, s) => n + s.length + 1, 0);
    }
    current.push(sentence);
    length += sentence.length + 1;
  }
  if (current.length > 0 && chunks.length < maxChunks) chunks.push(current.join(' '));
  return chunks.filter((c) => c.length >= MIN_CHUNK_CHARS);
}

export interface Ranked {
  /** Which thread it came from. */
  group: number;
  score: number;
}

export function cosine(a: number[], b: number[]): number {
  let dot = 0;
  let normA = 0;
  let normB = 0;
  for (let i = 0; i < a.length; i++) {
    dot += a[i] * b[i];
    normA += a[i] * a[i];
    normB += b[i] * b[i];
  }
  return dot / (Math.sqrt(normA) * Math.sqrt(normB) || 1);
}

/**
 * Best [limit] items overall, at most [perGroup] from any one thread so a
 * single busy thread can't crowd out other people's experiences.
 */
export function selectTop<T extends Ranked>(items: T[], limit: number, perGroup: number): T[] {
  const taken = new Map<number, number>();
  const selected: T[] = [];
  for (const item of [...items].sort((a, b) => b.score - a.score)) {
    const count = taken.get(item.group) ?? 0;
    if (count >= perGroup) continue;
    taken.set(item.group, count + 1);
    selected.push(item);
    if (selected.length >= limit) break;
  }
  return selected;
}

/**
 * How much a reply's votes should lift it: community approval matters, but
 * relevance to the person's situation matters more — log-scaled and small
 * next to cosine similarity (0–1).
 */
export function voteBoost(votes: number): number {
  return 0.04 * Math.log10(1 + Math.max(0, votes));
}

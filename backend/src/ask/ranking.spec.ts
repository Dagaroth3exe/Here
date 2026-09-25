import { chunkText, cosine, selectTop, voteBoost } from './ranking.js';

describe('chunkText', () => {
  it('keeps chunks near 700 chars and overlaps by a sentence', () => {
    const sentence = (i: number) => `Sentence number ${i} talks about a cafe in Sector 125 with good coffee.`;
    const chunks = chunkText(Array.from({ length: 40 }, (_, i) => sentence(i)).join(' '), 50);
    expect(chunks.length).toBeGreaterThan(1);
    for (const chunk of chunks) expect(chunk.length).toBeLessThanOrEqual(700 + sentence(0).length);
    const lastSentenceOfFirst = chunks[0].split(/(?<=\.)\s+/).at(-1)!;
    expect(chunks[1].startsWith(lastSentenceOfFirst)).toBe(true);
  });

  it('hard-splits long runs without punctuation (scraped menus)', () => {
    const chunks = chunkText('Home Menu Deals '.repeat(200), 50);
    expect(chunks.length).toBeGreaterThan(3);
    for (const chunk of chunks) expect(chunk.length).toBeLessThanOrEqual(700);
  });

  it('respects maxChunks and drops tiny fragments', () => {
    expect(chunkText('word. '.repeat(2000), 3)).toHaveLength(3);
    expect(chunkText('Too short.', 5)).toEqual([]);
  });
});

describe('cosine', () => {
  it('is 1 for the same direction and 0 for orthogonal vectors', () => {
    expect(cosine([1, 2, 3], [2, 4, 6])).toBeCloseTo(1);
    expect(cosine([1, 0], [0, 1])).toBeCloseTo(0);
    expect(cosine([0, 0], [1, 1])).toBe(0);
  });
});

describe('selectTop', () => {
  const item = (group: number, score: number) => ({ group, score });

  it('takes the best items but caps how many come from one thread', () => {
    const chosen = selectTop([item(0, 0.9), item(0, 0.8), item(0, 0.7), item(1, 0.6), item(2, 0.5)], 3, 2);
    expect(chosen).toEqual([item(0, 0.9), item(0, 0.8), item(1, 0.6)]);
  });
});

describe('voteBoost', () => {
  it('grows slowly with votes and ignores downvotes', () => {
    expect(voteBoost(0)).toBe(0);
    expect(voteBoost(-20)).toBe(0);
    expect(voteBoost(999)).toBeCloseTo(0.12);
    expect(voteBoost(10)).toBeLessThan(voteBoost(100));
  });
});

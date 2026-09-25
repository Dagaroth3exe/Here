import { cosine, selectTop, voteBoost } from './ranking.js';

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

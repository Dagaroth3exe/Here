import { pickRing, type Place } from './web-sources.js';

const at = (distanceM: number): Place => ({ name: `${distanceM} m`, kind: 'shop', lat: 0, lng: 0, distanceM });

describe('pickRing', () => {
  it('stays within 1 km when there are enough places there', () => {
    const ring = pickRing([at(2400), at(300), at(900), at(650), at(1800)], 5000);
    expect(ring?.radiusM).toBe(1000);
    expect(ring?.places.map((p) => p.distanceM)).toEqual([300, 650, 900]);
  });

  it('widens step by step, never jumping past the first sufficient ring', () => {
    // 1 within 1 km, 2 within 1.5 km, 3 within 2 km → 2 km, and nothing beyond it.
    const ring = pickRing([at(700), at(1400), at(1900), at(2900), at(4000)], 5000);
    expect(ring?.radiusM).toBe(2000);
    expect(ring?.places.map((p) => p.distanceM)).toEqual([700, 1400, 1900]);
  });

  it('only considers rings up to the queried radius', () => {
    expect(pickRing([at(700), at(1400), at(1900)], 1500)).toBeNull();
  });

  it('returns whatever is closest in the last ring when accepting fewer', () => {
    expect(pickRing([at(4200)], 5000)).toBeNull();
    expect(pickRing([at(4200)], 5000, true)).toEqual({ radiusM: 5000, places: [at(4200)] });
  });

  it('caps the list at 10 places', () => {
    const ring = pickRing(Array.from({ length: 25 }, (_, i) => at(100 + i * 10)), 5000);
    expect(ring?.radiusM).toBe(1000);
    expect(ring?.places).toHaveLength(10);
  });
});

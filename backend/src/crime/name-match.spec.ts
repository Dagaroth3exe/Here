import { describe, expect, it } from 'vitest';
import { isGeographicUnit, matchUnits, normalize, normalizeState } from './name-match.js';
import { parseDistrictTable } from './ncrb-table.js';

describe('matchUnits', () => {
  it('matches different spellings of the same district', () => {
    const m = matchUnits(['Gautam Buddha Nagar', 'Ghaziabad', 'Ghazipur'], ['Gautambudh Nagar', 'Ghaziabad', 'Ghazipur']);
    expect(m.get('Gautam Buddha Nagar')).toEqual(['Gautambudh Nagar']);
    expect(m.get('Ghaziabad')).toEqual(['Ghaziabad']);
    expect(m.get('Ghazipur')).toEqual(['Ghazipur']);
  });

  it('adds city and rural police of one district together', () => {
    const m = matchUnits(['Lucknow', 'Lalitpur'], ['Lucknow Commissionarate', 'Lucknow Grameen', 'Lalitpur']);
    expect(m.get('Lucknow')).toEqual(['Lucknow Commissionarate', 'Lucknow Grameen']);
  });

  it('keeps a district that shares a stem with a city apart', () => {
    const m = matchUnits(['Kanpur Nagar', 'Kanpur Dehat'], ['Kanpur Commissionarate', 'Kanpur Dehat', 'Kanpur Outer']);
    expect(m.get('Kanpur Dehat')).toEqual(['Kanpur Dehat']);
    expect(m.get('Kanpur Nagar')).toEqual(['Kanpur Commissionarate', 'Kanpur Outer']);
  });

  it("leaves out units that aren't places, and names it can't place", () => {
    const m = matchUnits(['Central', 'North West'], ['Central', 'North-West', 'Crime Branch', 'IGI Airport', 'GRP', 'Rohini']);
    expect(m.get('Central')).toEqual(['Central']);
    expect(m.get('North West')).toEqual(['North-West']);
    expect([...m.values()].flat()).not.toContain('Rohini');
    expect(isGeographicUnit('Mumbai Railway')).toBe(false);
  });

  it('knows official renames, only in the state they happened', () => {
    const k = matchUnits(['Gurgaon', 'Bangalore', 'Bangalore Rural'], ['Gurugram', 'Bengaluru City', 'Bengaluru District'], 'Haryāna');
    expect(k.get('Gurgaon')).toEqual(['Gurugram']);
    const ka = matchUnits(['Bangalore', 'Bangalore Rural', 'Bijapur'], ['Bengaluru City', 'Bengaluru District', 'Vijayapura'], 'Karnātaka');
    expect(ka.get('Bangalore')).toEqual(['Bengaluru City']);
    expect(ka.get('Bangalore Rural')).toEqual(['Bengaluru District']);
    expect(ka.get('Bijapur')).toEqual(['Vijayapura']);
    const cg = matchUnits(['Bijapur'], ['Vijayapura', 'Bijapur'], 'Chhattīsgarh');
    expect(cg.get('Bijapur')).toEqual(['Bijapur']);
  });

  it('leaves out crime-branch style units', () => {
    const m = matchUnits(['Jaipur'], ['Jaipur East', 'Jaipur Crime', 'Jaipur Rural']);
    expect(m.get('Jaipur')).toEqual(['Jaipur East', 'Jaipur Rural']);
    expect(isGeographicUnit('K.Railways')).toBe(false);
  });

  it('normalises diacritics and state prefixes', () => {
    expect(normalize('Mahārāshtra')).toBe('maharashtra');
    expect(normalizeState('NCT of Delhi')).toBe(normalizeState('Delhi'));
  });
});

describe('parseDistrictTable', () => {
  const csv = [
    '"Sl. No","State/UT","District","Offences affecting the Human Body - Murder (Sec.302 IPC) - Col. ( 3)","Offences affecting the Human Body - Attempt to Commit Murder (Sec.307 IPC) - Col. ( 15)","Offences affecting the Human Body - Rape (Sec.376 IPC) - Col. ( 60)","Offences against Property - Theft (Section 379 IPC) - Theft (Total) (Col.92+Col.93) - Col. ( 91)","Total Cognizable IPC crimes - Col. ( 144)"',
    '1,Uttar Pradesh,Gautambudh Nagar,53,40,29,"2,492",8230',
    '2,Total Districts,Total Districts,925,1,2,3,158547',
  ].join('\n');

  it('reads totals and crime heads by header text, skipping subtotal rows', () => {
    const rows = parseDistrictTable(csv);
    expect(rows).toEqual([
      { state: 'Uttar Pradesh', unit: 'Gautambudh Nagar', total: 8230, heads: { murder: 53, rape: 29, theft: 2492 } },
    ]);
  });

  it('refuses a table without a total column', () => {
    expect(() => parseDistrictTable('State/UT,District,Murder\nUP,X,1')).toThrow();
  });
});

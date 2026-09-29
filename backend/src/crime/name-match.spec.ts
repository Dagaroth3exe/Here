import { describe, expect, it } from 'vitest';
import { readFileSync } from 'node:fs';
import { districtsForCity, isGeographicUnit, matchUnits, normalize, normalizeState } from './name-match.js';
import { parseCityTable } from './ncrb-cities.js';
import { parseDistrictTable } from './ncrb-table.js';
import { readFirstSheet } from './xlsx.js';

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

describe('parseCityTable', () => {
  const rows = [
    ['TABLE 1B.1 - IPC/BNS Crimes in Metropolitan Cities - 2022-2024'],
    ['SL', 'City', '2022', '2023', '2024 IPC Cases', '2024 BNS Cases', '2024 Total (IPC+BNS)', 'Actual Population (in Lakhs) (2011)', 'Rate of Cognizable Crimes (2024)'],
    ['6', 'Ghaziabad (Uttar Pradesh)', '9860', '9227', '4856', '4107', '8963', '23.6', '379.9'],
    ['5', 'Delhi City', '298988', '323549', '136669', '138733', '275402', '163.1', '1688'],
    ['', 'TOTAL CITIES', '620356', '667351', '1', '1', '593096', '1140.4', '520.1'],
  ];

  it('reads each year and the latest rate by header, splitting out the state', () => {
    expect(parseCityTable(rows)).toEqual([
      { city: 'Ghaziabad', state: 'Uttar Pradesh', totals: { 2022: 9860, 2023: 9227, 2024: 8963 }, rate: 379.9, rateYear: 2024 },
      { city: 'Delhi', state: null, totals: { 2022: 298988, 2023: 323549, 2024: 275402 }, rate: 1688, rateYear: 2024 },
    ]);
  });
});

describe('districtsForCity', () => {
  it('finds the district a city is in, its suburbs, or a whole city-state', () => {
    expect(districtsForCity('Ghaziabad', 'Uttar Pradesh', ['Ghaziabad', 'Gautam Buddha Nagar', 'Ghazipur'])).toEqual(['Ghaziabad']);
    expect(districtsForCity('Mumbai', 'Mahārāshtra', ['Mumbai', 'Mumbai Suburban', 'Thane'])).toEqual(['Mumbai', 'Mumbai Suburban']);
    expect(districtsForCity('Delhi', 'Delhi', ['Central', 'East', 'New Delhi'])).toEqual(['Central', 'East', 'New Delhi']);
    expect(districtsForCity('Bengaluru', 'Karnātaka', ['Bangalore', 'Bangalore Rural', 'Mysore'])).toEqual(['Bangalore']);
    expect(districtsForCity('Kanpur', 'Uttar Pradesh', ['Kanpur Nagar', 'Kanpur Dehat'])).toEqual(['Kanpur Nagar']);
    expect(districtsForCity('Kochi', 'Kerala', ['Ernakulam', 'Kottayam'])).toEqual(['Ernakulam']);
    expect(districtsForCity('Ahmedabad', 'Gujarāt', ['Ahmadabad', 'Gandhinagar'])).toEqual(['Ahmadabad']);
  });
});

describe('readFirstSheet', () => {
  it("reads NCRB's real 2024 metropolitan-city spreadsheet", () => {
    const file = readFileSync(new URL('./__fixtures__/ncrb-2024-table-1b1.xlsx', import.meta.url));
    const cities = parseCityTable(readFirstSheet(file));
    expect(cities).toHaveLength(19);
    expect(cities.find((c) => c.city === 'Ghaziabad')).toEqual({
      city: 'Ghaziabad',
      state: 'Uttar Pradesh',
      totals: { 2022: 9860, 2023: 9227, 2024: 8963 },
      rate: 379.9,
      rateYear: 2024,
    });
  });
});

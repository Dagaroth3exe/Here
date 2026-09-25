import { namedIn } from './ask.service.js';

describe('namedIn', () => {
  it('keeps a place the question names', () => {
    expect(namedIn('where can i buy grocery near vaishali?', 'Vaishali')).toBe('Vaishali');
    expect(namedIn('household shops near Vaishali metro', 'Vaishali Metro, Ghaziabad')).toBe('Vaishali Metro');
    expect(namedIn('cafes near sector 18 market', 'Sector 18')).toBe('Sector 18');
  });

  it('drops a place the model filled in from context', () => {
    expect(namedIn('where can i buy grocery?', 'Sector 125')).toBeNull();
    expect(namedIn('good places to eat nearby', 'Noida')).toBeNull();
    // Only part of the place named isn't enough.
    expect(namedIn('cafes in sector 18', 'Sector 62')).toBeNull();
  });
});

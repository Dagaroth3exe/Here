/** The fixed set of things a Reachable user can say they're open to being
 * approached about — matches the product spec's "Reachability Preferences"
 * checkboxes. Kept as plain keys (not free text) so Ask HERE / Ping matching
 * can filter on them later; the human-readable label lives client-side. */
export const REACHABILITY_CATEGORIES = [
  'local_questions',
  'recommendations',
  'travel',
  'technology',
  'professional_advice',
  'study',
  'hobbies',
  'helping',
  'conversation',
  'friends',
  'dating',
] as const;

export type ReachabilityCategory = (typeof REACHABILITY_CATEGORIES)[number];

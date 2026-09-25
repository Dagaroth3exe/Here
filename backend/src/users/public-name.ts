/** Anything that reads like an email address or a phone number. */
const looksPrivate = (value: string) => value.includes('@') || /^\+?[\d\s()-]{6,}$/.test(value);

/**
 * The name other people see (map, Discover, chat). Never an email or phone
 * number: phone sign-ups used to get their number as their display name, and
 * accounts without a username used to fall back to their email.
 */
export function publicName(user: { username?: string | null; displayName?: string | null }): string {
  for (const candidate of [user.username, user.displayName]) {
    const name = candidate?.trim();
    if (name && !looksPrivate(name)) return name;
  }
  return 'Someone';
}

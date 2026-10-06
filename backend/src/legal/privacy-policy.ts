/**
 * The privacy policy, as one public page (the URL the app stores ask for).
 * Written from what the code actually does — keep it in step when that
 * changes: new data collected, a new outside service, a new retention rule.
 */

/** Bump when the policy text changes. */
export const POLICY_UPDATED = '6 October 2026';

export interface PolicyContact {
  /** Who runs HERE (person or company). */
  operator: string;
  email: string;
}

const escape = (text: string) =>
  text.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');

export function privacyPolicyHtml(contact: PolicyContact): string {
  const operator = escape(contact.operator);
  const email = escape(contact.email);
  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>HERE Privacy Policy</title>
<style>
  :root { --bg: #f5f3f9; --fg: #221733; --muted: #5d5470; --line: #ddd6ea; --accent: #6a3fd1; color-scheme: light; }
  @media (prefers-color-scheme: dark) {
    :root { --bg: #17141f; --fg: #edeaf5; --muted: #b3abc4; --line: #2f2a3b; --accent: #b8a0ff; color-scheme: dark; }
  }
  body { margin: 0; background: var(--bg); color: var(--fg); font: 16px/1.6 system-ui, -apple-system, 'Segoe UI', sans-serif; }
  main { max-width: 42rem; margin: 0 auto; padding: 2.5rem 1.25rem 4rem; }
  h1 { font-size: 1.9rem; line-height: 1.2; margin: 0 0 .25rem; }
  h2 { font-size: 1.2rem; margin: 2.2rem 0 .5rem; padding-top: 1.2rem; border-top: 1px solid var(--line); }
  h3 { font-size: 1rem; margin: 1.2rem 0 .3rem; }
  p, li { color: var(--fg); }
  .updated, .note { color: var(--muted); }
  ul { padding-left: 1.2rem; }
  li { margin: .25rem 0; }
  a { color: var(--accent); }
  strong { font-weight: 650; }
</style>
</head>
<body>
<main>
<h1>HERE Privacy Policy</h1>
<p class="updated">Last updated: ${POLICY_UPDATED}</p>

<p>HERE connects you with people nearby who can help, and lets you raise an emergency alert. To do that it needs some
personal information, including your location. This page explains what HERE collects, why, who sees it, how long
it is kept and how to delete it. HERE is run by <strong>${operator}</strong>. Questions: <a href="mailto:${email}">${email}</a>.</p>

<p>In short: we use your data only to run HERE. We don't sell it, we don't show ads, and the app has no advertising
or analytics trackers.</p>

<h2>What we collect</h2>

<h3>Your account</h3>
<ul>
  <li>The name you choose, and your password, which is stored only as a one-way scrypt hash, never in readable form.</li>
  <li>Your phone number, if you sign in with a code by text message.</li>
  <li>An ID from Google or Apple, if you sign in with them. We don't get your Google or Apple password.</li>
  <li>Passkeys or an authenticator app, if you set them up. Authenticator secrets are stored encrypted.</li>
  <li>The topics you're open to being contacted about, and your appearance and language settings.</li>
</ul>

<h3>Your location</h3>
<ul>
  <li><strong>While you're Reachable:</strong> your position is shared with other Reachable people nearby so they can
  find you on the map. It is rounded to about 110 metres before it is shared, held only in the server's memory while
  you're connected, and not written to our database. Turn Reachable off and you disappear from everyone's map.</li>
  <li><strong>When you raise an SOS alert:</strong> your precise location is shared with the people alerted, updated
  while the alert is open, and stored with the alert. Finding you quickly is the point of an SOS.</li>
  <li><strong>Area alerts:</strong> we use your location to tell you if people recently raised SOS alerts near you.
  Area figures are only shown when at least two different people raised alerts, and alerts from the last hour are left
  out, so no single alert can be identified.</li>
  <li><strong>Ask HERE:</strong> the approximate location of a question is stored with it, so answers can be local.</li>
</ul>

<h3>What you send and do</h3>
<ul>
  <li><strong>Chat messages</strong> and chat requests. They are stored on our server so they reach the other person.
  They are <strong>not end-to-end encrypted</strong>.</li>
  <li><strong>SOS alerts:</strong> the reason and message you add, who was alerted, and whether anyone flagged it as a
  false alarm. Two false alarms pause SOS for 30 days.</li>
  <li><strong>Ask HERE</strong> questions and answers. Other people see them without your name.</li>
  <li><strong>Safety:</strong> people you block and reports you file.</li>
  <li><strong>Notifications:</strong> an address that lets our notification server reach your phone.</li>
</ul>

<h2>How we use it</h2>
<ul>
  <li>To run HERE: showing who's nearby, delivering messages, alerting people near an SOS, answering Ask HERE questions
  and sending notifications.</li>
  <li>To keep people safe: enforcing blocks, handling reports and pausing SOS after repeated false alarms.</li>
  <li>To secure your account: sign-in, and limits on repeated code requests.</li>
</ul>
<p>We don't use your data for advertising, and we don't sell or rent it.</p>

<h2>Who can see it</h2>

<h3>Other HERE users</h3>
<ul>
  <li>Reachable people nearby see your name and your rounded location.</li>
  <li>People you chat with see your messages.</li>
  <li>People alerted by your SOS see your name, precise location, and the reason and message you added.</li>
  <li>Ask HERE questions and answers are shown without your name.</li>
</ul>

<h3>Services that help run HERE</h3>
<ul>
  <li><strong>MSG91</strong> receives your phone number to send sign-in codes.</li>
  <li><strong>Google</strong> and <strong>Apple</strong>, if you sign in with them.</li>
  <li><strong>OpenFreeMap</strong> serves the map. Your phone loads map images straight from them, so they see your IP
  address and the area you're looking at.</li>
  <li><strong>OpenStreetMap</strong> (Nominatim and Overpass) receives the approximate location of an Ask HERE question,
  to name the area and find nearby places.</li>
  <li>Search engines, <strong>Reddit</strong> and <strong>Stack Exchange</strong> receive the text of an Ask HERE
  question, to find what people said about similar situations. They don't receive your name or account.</li>
</ul>
<p>Ask HERE's AI answers are generated on our own servers, not by an outside AI company. Our servers, database and
notification service are run by us.</p>

<h3>When the law requires it</h3>
<p>We may disclose information if required by law, or where needed to protect someone's life or safety.</p>

<h2>How long we keep it</h2>
<ul>
  <li>Your account, messages, SOS alerts and Ask HERE content: until you delete your account.</li>
  <li>Your Reachable location: only while you're connected.</li>
  <li>Sign-in codes: a few minutes.</li>
  <li>After you delete your account, we keep only a note that it was deleted for 8 days, so old sign-ins stop working.</li>
</ul>

<h2>Deleting your account</h2>
<p>In the app, go to <strong>Profile → Settings → Delete account</strong>. This permanently deletes your profile and
sign-in methods, all your chats and messages (for you and the people you talked to), your SOS alerts and locations,
and your blocks, reports and settings. Any SOS alert still open is ended first. Ask HERE questions and answers stay
up anonymously, with no link to you. If you can't use the app, email <a href="mailto:${email}">${email}</a> from the
details on your account and we'll delete it.</p>

<h2>Your rights</h2>
<p>You can ask to see, correct or delete your personal data, or withdraw consent, by emailing
<a href="mailto:${email}">${email}</a>. If you're in India, you have these rights under the Digital Personal Data
Protection Act, 2023, and you can raise a grievance with us at the same address.</p>

<h2>Security</h2>
<p>Connections to HERE are encrypted (HTTPS). Passwords are stored only as hashes, and authenticator secrets are
encrypted. No system is perfectly secure, so if we learn of a breach that affects you, we'll tell you.</p>

<h2>Children</h2>
<p>HERE is meant for adults. Please don't use HERE if you're under 18.</p>

<h2>Changes</h2>
<p>If we change this policy, we'll update the date at the top. For important changes, we'll tell you in the app.</p>

<p class="note">Official crime figures shown in HERE come from the National Crime Records Bureau and contain no
personal information. Area boundaries are from geoBoundaries (ODbL).</p>
</main>
</body>
</html>`;
}

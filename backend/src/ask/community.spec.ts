import { parseRedditThread, parseThreadUrl, type Thread } from './community.js';

describe('parseThreadUrl', () => {
  it('recognises Reddit threads on any subdomain and cleans the title', () => {
    expect(
      parseThreadUrl('https://old.reddit.com/r/noida/comments/1ho214o/22m_shifting_to_noida/', '22M shifting to Noida : r/noida'),
    ).toEqual({
      platform: 'reddit',
      id: '1ho214o',
      title: '22M shifting to Noida',
      url: 'https://www.reddit.com/comments/1ho214o',
    });
  });

  it('recognises Stack Exchange questions, including standalone sites', () => {
    expect(parseThreadUrl('https://expatriates.stackexchange.com/questions/6293/renting', 'Renting from abroad')).toMatchObject({
      platform: 'stackexchange',
      id: '6293',
      site: 'expatriates',
    });
    expect(parseThreadUrl('https://superuser.com/questions/12/x', 'x')).toMatchObject({ site: 'superuser' });
  });

  it('ignores everything else', () => {
    expect(parseThreadUrl('https://www.reddit.com/r/noida/', 'r/noida')).toBeNull();
    expect(parseThreadUrl('https://meta.stackexchange.com/questions/1/x', 'x')).toBeNull();
    expect(parseThreadUrl('https://www.zomato.com/ncr/restaurants', 'Zomato')).toBeNull();
    expect(parseThreadUrl('not a url', 'x')).toBeNull();
  });
});

describe('parseRedditThread', () => {
  const thread: Thread = { platform: 'reddit', id: 'abc', title: 'fallback', url: 'https://www.reddit.com/comments/abc' };
  const comment = (author: string, body: string, extra: Record<string, unknown> = {}) => ({
    kind: 't1',
    data: { author, body, score: 12, created_utc: 1_700_000_000, permalink: `/r/noida/comments/abc/_/${author}/`, ...extra },
  });
  const long = 'I moved to Sector 62 last year and Sector 76 was cheaper with decent metro access.';

  it('keeps real top-level comments and their direct replies', () => {
    const json = [
      { data: { children: [{ data: { title: 'Shifting to Noida', subreddit_name_prefixed: 'r/noida' } }] } },
      {
        data: {
          children: [
            comment('alice', long, {
              replies: { data: { children: [comment('bob', `Agree. ${long}`, { replies: { data: { children: [comment('carol', `Deep. ${long}`)] } } })] } },
            }),
            { kind: 'more', data: {} },
          ],
        },
      },
    ];
    const replies = parseRedditThread(json, thread);
    expect(replies.map((r) => r.author)).toEqual(['u/alice', 'u/bob']);
    expect(replies[0]).toMatchObject({
      community: 'r/noida',
      threadTitle: 'Shifting to Noida',
      score: 12,
      url: 'https://www.reddit.com/r/noida/comments/abc/_/alice/',
      createdAt: '2023-11-14T22:13:20.000Z',
    });
  });

  it('drops deleted, removed, bot, stickied and too-short comments', () => {
    const json = [
      { data: { children: [{ data: {} }] } },
      {
        data: {
          children: [
            comment('[deleted]', long),
            comment('dave', '[removed]'),
            comment('AutoModerator', long),
            comment('mod', long, { stickied: true }),
            comment('erin', 'this'),
            comment('frank', long),
          ],
        },
      },
    ];
    expect(parseRedditThread(json, thread).map((r) => r.author)).toEqual(['u/frank']);
  });
});

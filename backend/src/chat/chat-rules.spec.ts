import { decideSend } from './chat-rules.js';

describe('decideSend', () => {
  const me = 'me';
  const them = 'them';

  it('makes first contact a request, unless the pair already chatted', () => {
    expect(decideSend(null, false, me)).toEqual({ action: 'request' });
    expect(decideSend(null, true, me)).toEqual({ action: 'grandfather' });
  });

  it('lets anyone send once accepted', () => {
    expect(decideSend({ status: 'accepted', requesterId: me }, true, me)).toEqual({ action: 'send' });
    expect(decideSend({ status: 'accepted', requesterId: me }, true, them)).toEqual({ action: 'send' });
  });

  it('holds the requester to one message until accepted', () => {
    expect(decideSend({ status: 'pending', requesterId: me }, true, me)).toEqual({ action: 'refuse', reason: 'awaiting' });
  });

  it('treats the recipient replying as accepting — even after declining', () => {
    expect(decideSend({ status: 'pending', requesterId: them }, true, me)).toEqual({ action: 'accept' });
    expect(decideSend({ status: 'declined', requesterId: them }, true, me)).toEqual({ action: 'accept' });
  });

  it('stops the requester once declined', () => {
    expect(decideSend({ status: 'declined', requesterId: me }, true, me)).toEqual({ action: 'refuse', reason: 'declined' });
  });
});

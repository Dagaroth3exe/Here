import { ConfigService } from '@nestjs/config';
import { UserEvents } from '../events/user-events.js';
import { PushService } from './push.service.js';

describe('PushService.internalAddress', () => {
  const config = new ConfigService({ NTFY_PUBLIC_URL: 'http://10.0.2.2:8090', NTFY_INTERNAL_URL: 'http://localhost:8090' });
  const push = new PushService({} as never, new UserEvents(), config);

  it('maps our ntfy topic URLs to the internal address', () => {
    expect(push.internalAddress('http://10.0.2.2:8090/upAbC123xyz?up=1')).toBe('http://localhost:8090/upAbC123xyz?up=1');
  });

  it('refuses anything else (SSRF guard)', () => {
    for (const bad of [
      'http://localhost:6379/upAbC123xyz',
      'http://10.0.2.2:5432/upAbC123xyz',
      'http://evil.example/upAbC123xyz',
      'http://user:pw@10.0.2.2:8090/upAbC123xyz',
      'http://10.0.2.2:8090/v1/health',
      'http://10.0.2.2:8090/../admin',
      'http://10.0.2.2:8090/short',
      'not a url',
    ]) {
      expect(push.internalAddress(bad)).toBeNull();
    }
  });
});

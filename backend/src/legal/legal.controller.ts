import { Controller, Get, Header } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { privacyPolicyHtml } from './privacy-policy.js';

/** Public pages the app stores link to — no sign-in needed. */
@Controller()
export class LegalController {
  constructor(private readonly config: ConfigService) {}

  @Get('privacy')
  @Header('Content-Type', 'text/html; charset=utf-8')
  @Header('Cache-Control', 'public, max-age=3600')
  privacy(): string {
    return privacyPolicyHtml({
      // Placeholders until set in .env (see deploy/.env.production.example).
      operator: this.config.get<string>('POLICY_OPERATOR') || '[operator name]',
      email: this.config.get<string>('POLICY_CONTACT_EMAIL') || '[contact email]',
    });
  }
}

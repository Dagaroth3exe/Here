import { Injectable, InternalServerErrorException, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

/**
 * Sends OTP codes via MSG91's transactional "Flow" API. Deliberately not
 * MSG91's stateful "OTP widget" API (which generates/stores/verifies codes
 * on MSG91's own servers) — all OTP generation, hashing, expiry, and rate
 * limiting lives in this app's own Redis (see AuthService), so this stays a
 * pure delivery step.
 */
@Injectable()
export class SmsService {
  private readonly logger = new Logger(SmsService.name);

  constructor(private readonly configService: ConfigService) {}

  async sendOtpSms(phone: string, code: string): Promise<void> {
    const authKey = this.configService.get<string>('MSG91_AUTH_KEY');
    const flowId = this.configService.get<string>('MSG91_FLOW_ID');
    const senderId = this.configService.get<string>('MSG91_SENDER_ID');

    if (!authKey || !flowId || !senderId) {
      if (this.configService.get<string>('NODE_ENV') === 'production') {
        throw new InternalServerErrorException('SMS gateway is not configured');
      }
      this.logger.warn(`[dev-mode, MSG91 not configured] OTP for ${phone}: ${code}`);
      return;
    }

    const response = await fetch('https://control.msg91.com/api/v5/flow/', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', authkey: authKey },
      body: JSON.stringify({
        flow_id: flowId,
        sender: senderId,
        mobiles: phone.replace('+', ''),
        OTP: code,
      }),
    });

    if (!response.ok) {
      throw new InternalServerErrorException(`Failed to send OTP SMS (${response.status})`);
    }
  }
}

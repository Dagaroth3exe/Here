import { Inject, Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { InjectRepository } from '@nestjs/typeorm';
import type { Redis } from 'ioredis';
import { generateSecret, generateURI, verify as verifyTotp } from 'otplib';
import {
  generateAuthenticationOptions,
  generateRegistrationOptions,
  verifyAuthenticationResponse,
  verifyRegistrationResponse,
  type AuthenticationResponseJSON,
  type PublicKeyCredentialCreationOptionsJSON,
  type PublicKeyCredentialRequestOptionsJSON,
  type RegistrationResponseJSON,
  type WebAuthnCredential,
} from '@simplewebauthn/server';
import { Repository } from 'typeorm';
import { REDIS_CLIENT } from '../redis/redis.module.js';
import { User } from '../users/user.entity.js';
import { UsersService } from '../users/users.service.js';
import { hashPassword, verifyPassword } from './password.util.js';
import { TotpCrypto } from './totp-crypto.js';
import { TotpCredential } from './totp-credential.entity.js';
import { WebauthnCredential } from './webauthn-credential.entity.js';

const CHALLENGE_TTL_SECONDS = 5 * 60;
const TOTP_PERIOD_SECONDS = 30;
/** ±1 time step of clock drift tolerance, matching typical authenticator apps. */
const TOTP_EPOCH_TOLERANCE_SECONDS = 30;

@Injectable()
export class AuthService {
  private readonly rpName: string;
  private readonly rpID: string;
  private readonly origin: string;

  constructor(
    private readonly usersService: UsersService,
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
    @Inject(REDIS_CLIENT) private readonly redis: Redis,
    @InjectRepository(WebauthnCredential)
    private readonly credentialsRepository: Repository<WebauthnCredential>,
    @InjectRepository(TotpCredential)
    private readonly totpRepository: Repository<TotpCredential>,
    private readonly totpCrypto: TotpCrypto,
  ) {
    this.rpName = this.configService.getOrThrow('RP_NAME');
    this.rpID = this.configService.getOrThrow('RP_ID');
    this.origin = this.configService.getOrThrow('ORIGIN');
  }

  private challengeKey(email: string): string {
    return `webauthn:challenge:${email}`;
  }

  async generateRegistrationOptionsFor(
    email: string,
  ): Promise<PublicKeyCredentialCreationOptionsJSON> {
    const existing = await this.usersService.findByEmail(email);
    if (existing) {
      throw new UnauthorizedException('An account with this email already exists');
    }

    const options = await generateRegistrationOptions({
      rpName: this.rpName,
      rpID: this.rpID,
      userName: email,
      attestationType: 'none',
      authenticatorSelection: {
        residentKey: 'preferred',
        userVerification: 'preferred',
      },
    });

    await this.redis.set(
      this.challengeKey(email),
      options.challenge,
      'EX',
      CHALLENGE_TTL_SECONDS,
    );

    return options;
  }

  async verifyRegistration(
    email: string,
    response: RegistrationResponseJSON,
  ): Promise<{ accessToken: string }> {
    const expectedChallenge = await this.redis.get(this.challengeKey(email));
    if (!expectedChallenge) {
      throw new UnauthorizedException('Registration challenge expired, try again');
    }

    const verification = await verifyRegistrationResponse({
      response,
      expectedChallenge,
      expectedOrigin: this.origin,
      expectedRPID: this.rpID,
    });

    if (!verification.verified || !verification.registrationInfo) {
      throw new UnauthorizedException('Passkey registration could not be verified');
    }

    await this.redis.del(this.challengeKey(email));

    const { credential, credentialDeviceType, credentialBackedUp } =
      verification.registrationInfo;

    const user = await this.usersService.create(email);
    const savedCredential = this.credentialsRepository.create({
      userId: user.id,
      credentialId: credential.id,
      publicKey: Buffer.from(credential.publicKey).toString('base64url'),
      counter: credential.counter,
      transports: credential.transports ?? null,
      deviceType: credentialDeviceType,
      backedUp: credentialBackedUp,
    });
    await this.credentialsRepository.save(savedCredential);

    return { accessToken: this.issueToken(user) };
  }

  async generateAuthenticationOptionsFor(
    email: string,
  ): Promise<PublicKeyCredentialRequestOptionsJSON> {
    const user = await this.usersService.findByEmail(email);
    if (!user) {
      throw new UnauthorizedException('No account found for this email');
    }

    const options = await generateAuthenticationOptions({
      rpID: this.rpID,
      userVerification: 'preferred',
      allowCredentials: user.credentials.map((cred) => ({
        id: cred.credentialId,
        transports: cred.transports ?? undefined,
      })),
    });

    await this.redis.set(
      this.challengeKey(email),
      options.challenge,
      'EX',
      CHALLENGE_TTL_SECONDS,
    );

    return options;
  }

  async verifyAuthentication(
    email: string,
    response: AuthenticationResponseJSON,
  ): Promise<{ accessToken: string }> {
    const expectedChallenge = await this.redis.get(this.challengeKey(email));
    if (!expectedChallenge) {
      throw new UnauthorizedException('Authentication challenge expired, try again');
    }

    const user = await this.usersService.findByEmail(email);
    if (!user) {
      throw new UnauthorizedException('No account found for this email');
    }

    const storedCredential = user.credentials.find(
      (cred) => cred.credentialId === response.id,
    );
    if (!storedCredential) {
      throw new UnauthorizedException('Passkey not recognized for this account');
    }

    const credentialForVerification: WebAuthnCredential = {
      id: storedCredential.credentialId,
      publicKey: Buffer.from(storedCredential.publicKey, 'base64url'),
      counter: Number(storedCredential.counter),
      transports: storedCredential.transports ?? undefined,
    };

    const verification = await verifyAuthenticationResponse({
      response,
      expectedChallenge,
      expectedOrigin: this.origin,
      expectedRPID: this.rpID,
      credential: credentialForVerification,
    });

    if (!verification.verified) {
      throw new UnauthorizedException('Passkey authentication failed');
    }

    await this.redis.del(this.challengeKey(email));
    storedCredential.counter = verification.authenticationInfo.newCounter;
    await this.credentialsRepository.save(storedCredential);

    return { accessToken: this.issueToken(user) };
  }

  /**
   * Starts (or restarts, if not yet confirmed) TOTP setup for an account.
   * Creates the account if it doesn't exist yet, so email+TOTP can be used
   * as a standalone login method, not only as an addition to an existing
   * passkey account.
   */
  async setupTotp(email: string): Promise<{ secret: string; otpauthUrl: string }> {
    let user = await this.usersService.findByEmail(email);
    if (!user) {
      user = await this.usersService.create(email);
    } else if (user.totpCredential?.confirmed) {
      throw new UnauthorizedException(
        'TOTP is already set up for this account',
      );
    }

    const secret = generateSecret();
    const secretEncrypted = this.totpCrypto.encrypt(secret);

    if (user.totpCredential) {
      user.totpCredential.secretEncrypted = secretEncrypted;
      user.totpCredential.confirmed = false;
      user.totpCredential.lastUsedStep = null;
      await this.totpRepository.save(user.totpCredential);
    } else {
      await this.totpRepository.save(
        this.totpRepository.create({ userId: user.id, secretEncrypted }),
      );
    }

    const otpauthUrl = generateURI({ issuer: this.rpName, label: email, secret });
    return { secret, otpauthUrl };
  }

  /** Confirms the code from the just-scanned QR actually works, completing setup. */
  async confirmTotp(email: string, code: string): Promise<{ accessToken: string }> {
    const user = await this.usersService.findByEmail(email);
    const credential = user?.totpCredential;
    if (!user || !credential) {
      throw new UnauthorizedException('No TOTP setup in progress for this account');
    }

    const result = await this.verifyTotpCode(credential, code);
    credential.confirmed = true;
    credential.lastUsedStep = result.timeStep;
    await this.totpRepository.save(credential);

    return { accessToken: this.issueToken(user) };
  }

  async loginWithTotp(email: string, code: string): Promise<{ accessToken: string }> {
    const user = await this.usersService.findByEmail(email);
    const credential = user?.totpCredential;
    if (!user || !credential || !credential.confirmed) {
      throw new UnauthorizedException('TOTP is not set up for this account');
    }

    const result = await this.verifyTotpCode(credential, code);
    credential.lastUsedStep = result.timeStep;
    await this.totpRepository.save(credential);

    return { accessToken: this.issueToken(user) };
  }

  private async verifyTotpCode(
    credential: TotpCredential,
    code: string,
  ): Promise<{ timeStep: number }> {
    const secret = this.totpCrypto.decrypt(credential.secretEncrypted);
    // TypeORM returns `bigint` columns as strings (JS numbers can't safely
    // hold all 64-bit values) — otplib requires a real integer here.
    const afterTimeStep =
      credential.lastUsedStep != null ? Number(credential.lastUsedStep) : undefined;
    const result = await verifyTotp({
      secret,
      token: code,
      period: TOTP_PERIOD_SECONDS,
      epochTolerance: TOTP_EPOCH_TOLERANCE_SECONDS,
      afterTimeStep,
    });

    if (!result.valid) {
      throw new UnauthorizedException('Incorrect or already-used code');
    }

    const currentTimeStep = Math.floor(Date.now() / 1000 / TOTP_PERIOD_SECONDS);
    return { timeStep: currentTimeStep + (result.delta ?? 0) };
  }

  async signupWithPassword(name: string, password: string): Promise<{ accessToken: string }> {
    const existing = await this.usersService.findByUsername(name);
    if (existing) {
      throw new UnauthorizedException('That name is already taken');
    }

    const passwordHash = await hashPassword(password);
    const user = await this.usersService.createWithPassword(name, passwordHash);
    return { accessToken: this.issueToken(user) };
  }

  async loginWithPassword(name: string, password: string): Promise<{ accessToken: string }> {
    const user = await this.usersService.findByUsername(name);
    if (!user?.passwordHash || !(await verifyPassword(password, user.passwordHash))) {
      throw new UnauthorizedException('Incorrect name or password');
    }

    return { accessToken: this.issueToken(user) };
  }

  private issueToken(user: User): string {
    return this.jwtService.sign({ sub: user.id, email: user.email, username: user.username });
  }
}

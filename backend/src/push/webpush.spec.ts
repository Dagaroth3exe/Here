import { createDecipheriv, createECDH, hkdfSync, randomBytes } from 'node:crypto';
import { encryptWebPush } from './webpush.js';

/** The phone's side of RFC 8291, to check the encryption round-trips. */
function decrypt(body: Buffer, receiver: ReturnType<typeof createECDH>, authSecret: Buffer): string {
  const salt = body.subarray(0, 16);
  const keyIdLength = body[20];
  const senderKey = body.subarray(21, 21 + keyIdLength);
  const ciphertext = body.subarray(21 + keyIdLength);
  const receiverKey = receiver.getPublicKey();
  const shared = receiver.computeSecret(senderKey);
  const keyInfo = Buffer.concat([Buffer.from('WebPush: info\0'), receiverKey, senderKey]);
  const ikm = Buffer.from(hkdfSync('sha256', shared, authSecret, keyInfo, 32));
  const key = Buffer.from(hkdfSync('sha256', ikm, salt, Buffer.from('Content-Encoding: aes128gcm\0'), 16));
  const nonce = Buffer.from(hkdfSync('sha256', ikm, salt, Buffer.from('Content-Encoding: nonce\0'), 12));
  const decipher = createDecipheriv('aes-128-gcm', key, nonce);
  decipher.setAuthTag(ciphertext.subarray(ciphertext.length - 16));
  const padded = Buffer.concat([decipher.update(ciphertext.subarray(0, ciphertext.length - 16)), decipher.final()]);
  expect(padded[padded.length - 1]).toBe(2); // last-record delimiter
  return padded.subarray(0, padded.length - 1).toString();
}

describe('encryptWebPush', () => {
  const receiver = createECDH('prime256v1');
  receiver.generateKeys();
  const authSecret = randomBytes(16);
  const p256dh = receiver.getPublicKey().toString('base64url');
  const auth = authSecret.toString('base64url');

  it('produces an aes128gcm body the phone can decrypt', () => {
    const message = JSON.stringify({ title: 'Priya', body: 'See you at the metro gate 2?' });
    const body = encryptWebPush(Buffer.from(message), p256dh, auth);
    expect(body.readUInt32BE(16)).toBe(4096);
    expect(body[20]).toBe(65);
    expect(decrypt(body, receiver, authSecret)).toBe(message);
  });

  it('uses a fresh salt and key each time', () => {
    const a = encryptWebPush(Buffer.from('same'), p256dh, auth);
    const b = encryptWebPush(Buffer.from('same'), p256dh, auth);
    expect(a.equals(b)).toBe(false);
  });

  it('rejects malformed keys', () => {
    expect(() => encryptWebPush(Buffer.from('x'), 'short', auth)).toThrow('Invalid push keys');
  });
});

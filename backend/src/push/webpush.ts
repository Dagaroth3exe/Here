import { createCipheriv, createECDH, hkdfSync, randomBytes } from 'node:crypto';

/**
 * Web Push message encryption (RFC 8291, "aes128gcm" content coding) — what
 * UnifiedPush expects, so push servers (ntfy, or a public one a user picks)
 * only ever see ciphertext. Built on node:crypto rather than a dependency.
 *
 * [p256dh] is the phone's P-256 public key (uncompressed, base64url) and
 * [auth] its 16-byte auth secret (base64url), both from its registration.
 */
export function encryptWebPush(plaintext: Buffer, p256dh: string, auth: string): Buffer {
  const receiverKey = Buffer.from(p256dh, 'base64url');
  const authSecret = Buffer.from(auth, 'base64url');
  if (receiverKey.length !== 65 || authSecret.length !== 16) throw new Error('Invalid push keys');

  const sender = createECDH('prime256v1');
  const senderKey = sender.generateKeys();
  const sharedSecret = sender.computeSecret(receiverKey);

  // RFC 8291 §3.3–3.4: combine the ECDH secret with the auth secret, then
  // derive the content key and nonce from a fresh salt (RFC 8188).
  const keyInfo = Buffer.concat([Buffer.from('WebPush: info\0'), receiverKey, senderKey]);
  const ikm = Buffer.from(hkdfSync('sha256', sharedSecret, authSecret, keyInfo, 32));
  const salt = randomBytes(16);
  const contentKey = Buffer.from(hkdfSync('sha256', ikm, salt, Buffer.from('Content-Encoding: aes128gcm\0'), 16));
  const nonce = Buffer.from(hkdfSync('sha256', ikm, salt, Buffer.from('Content-Encoding: nonce\0'), 12));

  // One record: the message plus the 0x02 "last record" delimiter.
  const cipher = createCipheriv('aes-128-gcm', contentKey, nonce);
  const ciphertext = Buffer.concat([cipher.update(Buffer.concat([plaintext, Buffer.from([2])])), cipher.final(), cipher.getAuthTag()]);

  // Header: salt (16) | record size (4, big-endian) | key id length (1) | sender public key (65).
  const recordSize = Buffer.alloc(4);
  recordSize.writeUInt32BE(4096);
  return Buffer.concat([salt, recordSize, Buffer.from([senderKey.length]), senderKey, ciphertext]);
}

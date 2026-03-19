import crypto from 'node:crypto';

const SHA256_PREFIX = 'sha256:';

export function createLocalPinHash(pin: string): string {
  const digest = crypto.createHash('sha256').update(pin).digest('hex');
  return `${SHA256_PREFIX}${digest}`;
}

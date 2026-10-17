import { fileURLToPath } from 'node:url';
import { createPushRelay } from './relay.mjs';

const { server } = await createPushRelay({
  publicBase: process.env.PUSH_PUBLIC_BASE,
  token: process.env.PUSH_RELAY_TOKEN,
  file: process.env.PUSH_STORE_FILE || fileURLToPath(new URL('../../data/push-subscriptions.local.json', import.meta.url))
});
server.listen(Number(process.env.PUSH_PORT || 8788), process.env.PUSH_HOST || '127.0.0.1', () => {
  console.log('Harmony X push relay ready');
});
for (const signal of ['SIGTERM', 'SIGINT']) process.on(signal, () => server.close());

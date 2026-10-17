// Gateway entry point: loads persisted sessions, builds the transaction-id
// provider chain, then serves the app-facing REST surface.
import { createServer, GATEWAY_TOKEN, HOST, PORT } from './gateway.mjs';
import { sessionStore } from './session-store.mjs';
import { createDefaultTransactionIdService } from './x/transaction-id.mjs';
import { OPERATION_COUNT } from './x/operations.generated.mjs';
import { log } from './util.mjs';

await sessionStore.load();
globalThis.__harmonyxTransactionIds = await createDefaultTransactionIdService();

const server = createServer();
server.listen(PORT, HOST, () => {
  log('info', `harmonyx-gateway listening on http://${HOST}:${PORT}`, {
    operations: OPERATION_COUNT,
    sessions: sessionStore.list().length,
    gatewayToken: GATEWAY_TOKEN.length > 0 ? 'configured' : 'not set (loopback only)'
  });
});

for (const signal of ['SIGINT', 'SIGTERM']) {
  process.on(signal, () => {
    log('info', `${signal} received, shutting down`);
    server.close(() => process.exit(0));
  });
}

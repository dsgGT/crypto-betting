// daemon/src/config.ts
import 'dotenv-flow/config';

export const RPC_URL          = process.env.RPC_URL!;           // JSON-RPC endpoint
export const CONTRACT_ADDRESS = process.env.CONTRACT_ADDRESS!;  // WagerManager
export const DAEMON_PRIVATE_KEY = process.env.DAEMON_PRIVATE_KEY!; // (unused now)
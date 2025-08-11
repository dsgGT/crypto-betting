// daemon/src/config.ts
import { z } from 'zod';

const Env = z.object({
  RPC_URL: z.string().url(),
  CONTRACT_ADDRESS: z.string().regex(/^0x[a-fA-F0-9]{40}$/),
  DAEMON_PRIVATE_KEY: z.string().regex(/^0x[a-fA-F0-9]{64}$/),
  ATTESTOR_PK_B: z.string().regex(/^0x[a-fA-F0-9]{64}$/),
  FETCH_RETRY_COUNT: z.coerce.number().optional().default(3),
});
export type Config = z.infer<typeof Env>;
export const cfg = Env.parse(process.env);
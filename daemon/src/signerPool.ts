// daemon/src/signerPool.ts
import { createWalletClient, http, type Address } from 'viem';
import { defineChain } from 'viem';

// Define local Anvil chain  
const anvilChain = defineChain({
  id: 31337,
  name: 'Anvil',
  nativeCurrency: {
    decimals: 18,
    name: 'Ether',
    symbol: 'ETH',
  },
  rpcUrls: {
    default: {
      http: ['http://localhost:8545'],
    },
  },
});
import { privateKeyToAccount } from 'viem/accounts';
import type { SignatureBundle } from './types.ts';
import { cfg } from './config.ts';

const transport = http(cfg.RPC_URL, { timeout: 30_000 });

const accountA = privateKeyToAccount(cfg.DAEMON_PRIVATE_KEY as `0x${string}`);
const accountB = privateKeyToAccount(cfg.ATTESTOR_PK_B     as `0x${string}`);

const clientA = createWalletClient({ chain: anvilChain, transport, account: accountA });
const clientB = createWalletClient({ chain: anvilChain, transport, account: accountB });

export async function collectSignatures(
  id: bigint,
  payload: `0x${string}`
): Promise<SignatureBundle> {
  const domain = {
    name: 'CheckmateArena',
    version: '1',
    chainId: anvilChain.id,
    verifyingContract: cfg.CONTRACT_ADDRESS as Address,
  };
  const types = {
    Data: [
      { name: 'id', type: 'uint256' },
      { name: 'payload', type: 'bytes32' },
    ],
  };
  const message = { id, payload };

  const sig1 = await clientA.signTypedData({
    domain, types, message, primaryType: 'Data'
  });
  const sig2 = await clientB.signTypedData({
    domain, types, message, primaryType: 'Data'
  });

  return { sigs: [sig1, sig2], winner: accountA.address };
}
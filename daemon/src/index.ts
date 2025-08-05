import { createPublicClient, http } from 'viem';
import { privateKeyToAccount } from 'viem/accounts';
import { baseSepolia, localhost } from 'viem/chains';
import type { Abi } from 'viem';

import { RPC_URL, CONTRACT_ADDRESS } from './config.ts';

import rawAbi from './WagerAbi.json' with { type: 'json' };
const ABI = rawAbi as Abi;

const client = createPublicClient({
  chain: localhost,
  transport: http(RPC_URL),
});

client.watchContractEvent({
  address: CONTRACT_ADDRESS as `0x${string}`,
  abi: ABI,
  eventName: 'MatchFunded',
  onError: (error) => {
    console.error('Event watching error:', error);
  },            
  onLogs: (logs) => {
    for (const log of logs) {
      console.log(log);
      // TypeScript doesn't know about 'args' on generic Log type, so we need type assertion
      const { id, opponent } = (log as any).args as { id: bigint; opponent: string };
      console.log(`💰 match ${id} funded by ${opponent}`);
    }
  },
});

// ... existing code ...
console.log('🟢 daemon listening – Ctrl-C to exit');

// Add this debug info:
console.log('RPC URL:', RPC_URL);
console.log('Contract Address:', CONTRACT_ADDRESS);
console.log('Chain:', localhost.name);
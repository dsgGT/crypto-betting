// daemon/src/index.ts
import 'dotenv/config';
import { createPublicClient, createWalletClient, http, type GetContractEventsReturnType } from 'viem';
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
import pRetry from 'p-retry';
import type { Abi } from 'viem';
import { cfg } from './config.ts';
import { collectSignatures } from './signerPool.ts';
import { fetchGameHash } from './resultFetcher.ts';
import WagerAbiJson from './WagerAbi.json' with { type: 'json' };

const ABI = WagerAbiJson as Abi;
type FundedLogs = GetContractEventsReturnType<typeof ABI, 'MatchFunded'>;
type FundedLog  = FundedLogs[number];

const transport = http(cfg.RPC_URL, { timeout: 30_000 });
const publicClient = createPublicClient({ chain: anvilChain, transport });
const walletClient = createWalletClient({
  chain:  anvilChain,
  transport,
  account: privateKeyToAccount(cfg.DAEMON_PRIVATE_KEY as `0x${string}`)
});

publicClient.watchContractEvent<typeof ABI, 'MatchFunded'>({
  address:   cfg.CONTRACT_ADDRESS as `0x${string}`,
  abi:       ABI,
  eventName: 'MatchFunded',
  poll: true,
  pollingInterval: 5000, // Poll every 5 seconds instead of using filters
  onLogs: async (logs) => {
    for (const { args: { id } } of logs as FundedLog[]) {
      console.log(`💰 MatchFunded #${id}`);

      try {
        // 1. get oracle hash
        const gameHash = await fetchGameHash(id);
                 // 2. pinResult
         const pinSigs = await collectSignatures(id, gameHash);
         await pRetry(
           () => walletClient.writeContract({
             address: cfg.CONTRACT_ADDRESS as `0x${string}`,
             abi:      ABI,
             functionName: 'pinResult',
             args:     [id, gameHash, pinSigs.sigs],
           }),
           { retries: 3 }
         );
        console.log(`📌 pinned #${id}`);

        // 3. settle: hash the winner address as payload
        const { winner } = await collectSignatures(id, gameHash);
        const winnerPayload = `0x${BigInt(winner).toString(16).padStart(64, '0')}` as `0x${string}`;

                 const settleSigs = await collectSignatures(id, winnerPayload);
         await pRetry(
           () => walletClient.writeContract({
             address: cfg.CONTRACT_ADDRESS as `0x${string}`,
             abi:      ABI,
             functionName: 'settle',
             args:     [id, winner, settleSigs.sigs],
           }),
           { retries: 3 }
         );
        console.log(`🏁 settled #${id}`);
      } catch (err) {
        console.error(`⚠️ error handling #${id}`, err);
      }
    }
  },
  onError: (err) => {
    console.error('🔴 watcher error', err);
  }
});

console.log('🟢 daemon live – watching for MatchFunded on localhost (chain-ID 31337)');
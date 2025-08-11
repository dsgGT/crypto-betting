// daemon/src/resultFetcher.ts
import pRetry from 'p-retry';
import { keccak256, toHex } from 'viem';
import { cfg } from './config.ts';

async function fetchRawResult(matchId: bigint): Promise<string> {
  // TODO: wire up to real API, e.g. Lichess REST / your db
  // for now we simulate:
  return `dummy-PGN-for-${matchId}`;
}

export async function fetchGameHash(matchId: bigint): Promise<`0x${string}`> {
  const pgn = await pRetry(
    () => fetchRawResult(matchId),
    { retries: cfg.FETCH_RETRY_COUNT }
  );
  return keccak256(toHex(pgn));
}
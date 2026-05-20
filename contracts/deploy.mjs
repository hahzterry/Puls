/**
 * Deploy PulsMarket to Arc Testnet
 *
 * 1. Go to https://remix.ethereum.org
 * 2. Create a new file, paste the contents of src/PulsMarket.sol
 * 3. Compile (Solidity 0.8.24, optimizer ON, 200 runs)
 * 4. In the Compilation Details, copy the BYTECODE → object field (hex string)
 * 5. Paste it below as BYTECODE
 * 6. Set PRIVATE_KEY in .env
 * 7. Run: node deploy.mjs
 */

import 'dotenv/config';
import { createWalletClient, createPublicClient, http } from 'viem';
import { privateKeyToAccount } from 'viem/accounts';
import { arcTestnet } from 'viem/chains';

// ── Paste bytecode from Remix here ────────────────────────────────────────────
const BYTECODE = process.env.BYTECODE || '';
// ─────────────────────────────────────────────────────────────────────────────

const ABI = [
  { type: 'constructor', inputs: [
    { name: '_usdc', type: 'address' },
    { name: '_question', type: 'string' },
    { name: '_deadline', type: 'uint256' },
    { name: '_initialLiquidity', type: 'uint256' },
  ], stateMutability: 'nonpayable' },
  { type: 'function', name: 'buyYes', inputs: [{ name: 'amount', type: 'uint256' }], stateMutability: 'nonpayable' },
  { type: 'function', name: 'buyNo',  inputs: [{ name: 'amount', type: 'uint256' }], stateMutability: 'nonpayable' },
  { type: 'function', name: 'resolve', inputs: [{ name: '_outcome', type: 'bool' }], stateMutability: 'nonpayable' },
  { type: 'function', name: 'claim',  inputs: [], stateMutability: 'nonpayable' },
  { type: 'function', name: 'getMarketInfo', inputs: [], outputs: [
    { name: '_question', type: 'string' },
    { name: '_deadline', type: 'uint256' },
    { name: '_resolved', type: 'bool' },
    { name: '_outcome', type: 'bool' },
    { name: '_poolYes', type: 'uint256' },
    { name: '_poolNo', type: 'uint256' }
  ], stateMutability: 'view' },
];

const USDC = '0x3600000000000000000000000000000000000000';

async function deploy() {
  if (!BYTECODE) {
    console.error('❌ BYTECODE is empty. Paste the compiled bytecode from Remix into deploy.mjs or set BYTECODE env var.');
    process.exit(1);
  }

  const pk = process.env.PRIVATE_KEY;
  if (!pk) { console.error('❌ Set PRIVATE_KEY in .env'); process.exit(1); }

  const account = privateKeyToAccount(pk);
  const walletClient = createWalletClient({ account, chain: arcTestnet, transport: http() });
  const publicClient = createPublicClient({ chain: arcTestnet, transport: http() });

  const question = process.env.MARKET_QUESTION || 'Will Bitcoin close above $100k this quarter?';
  const deadline = BigInt(Math.floor(Date.now() / 1000) + 30 * 24 * 3600);
  const initialLiquidity = 10000000n; // 10 USDC initial liquidity

  console.log(`Deploying from: ${account.address}`);
  console.log(`Question: ${question}`);
  console.log(`Chain: Arc Testnet (5042002)`);

  const hash = await walletClient.deployContract({
    abi: ABI,
    bytecode: BYTECODE.startsWith('0x') ? BYTECODE : `0x${BYTECODE}`,
    args: [USDC, question, deadline, initialLiquidity],
  });

  console.log(`Tx: ${hash}`);
  const receipt = await publicClient.waitForTransactionReceipt({ hash });
  console.log(`\n✅ Contract deployed: ${receipt.contractAddress}`);
  console.log(`Explorer: https://testnet.arcscan.app/address/${receipt.contractAddress}`);
  console.log(`\nAdd to backend/.env:\nMARKET_CONTRACT=${receipt.contractAddress}`);
}

deploy().catch(console.error);

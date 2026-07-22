import fs from 'fs';
import path from 'path';
import 'dotenv/config';
import { createWalletClient, createPublicClient, http } from 'viem';
import { privateKeyToAccount } from 'viem/accounts';
import { arcTestnet } from 'viem/chains';

const USDC = process.env.USDC_ADDRESS || '0x3600000000000000000000000000000000000000';

async function deploy() {
  const pk = process.env.PRIVATE_KEY;
  if (!pk) {
    console.error('❌ Set PRIVATE_KEY in .env');
    process.exit(1);
  }

  const account = privateKeyToAccount(pk.startsWith('0x') ? pk : `0x${pk}`);
  const walletClient = createWalletClient({ account, chain: arcTestnet, transport: http(process.env.ARC_RPC_URL || undefined) });
  const publicClient = createPublicClient({ chain: arcTestnet, transport: http(process.env.ARC_RPC_URL || undefined) });

  const artifactPath = path.resolve('./out/LMSRMarket.sol/LMSRMarket.json');
  if (!fs.existsSync(artifactPath)) {
    console.error('❌ Artifact not found. Please run `forge build` first.');
    process.exit(1);
  }

  const artifact = JSON.parse(fs.readFileSync(artifactPath, 'utf-8'));
  const ABI = artifact.abi;
  const BYTECODE = artifact.bytecode.object;

  const question = process.env.MARKET_QUESTION || 'Will Bitcoin close above $100k this quarter?';
  const deadline = BigInt(Math.floor(Date.now() / 1000) + 30 * 24 * 3600);
  const bParam = 10_000_000n; // b = 10 USDC

  console.log(`Deploying LMSRMarket from: ${account.address}`);
  console.log(`Question: ${question}`);
  console.log(`Chain: Arc Testnet (5042002)`);

  const hash = await walletClient.deployContract({
    abi: ABI,
    bytecode: BYTECODE.startsWith('0x') ? BYTECODE : `0x${BYTECODE}`,
    args: [USDC, question, deadline, bParam],
  });

  console.log(`Tx: ${hash}`);
  const receipt = await publicClient.waitForTransactionReceipt({ hash });
  console.log(`\n✅ Contract deployed: ${receipt.contractAddress}`);

  console.log('Approving USDC for funding...');
  const { request: approveReq } = await publicClient.simulateContract({
    account,
    address: USDC,
    abi: [{ type: 'function', name: 'approve', inputs: [{ name: 'spender', type: 'address' }, { name: 'amount', type: 'uint256' }], outputs: [{ name: '', type: 'bool' }], stateMutability: 'nonpayable' }],
    functionName: 'approve',
    args: [receipt.contractAddress, bParam],
  });
  const approveHash = await walletClient.writeContract(approveReq);
  await publicClient.waitForTransactionReceipt({ hash: approveHash });

  console.log('Funding LMSR Market...');
  const { request: fundReq } = await publicClient.simulateContract({
    account,
    address: receipt.contractAddress,
    abi: ABI,
    functionName: 'fund',
  });
  const fundHash = await walletClient.writeContract(fundReq);
  await publicClient.waitForTransactionReceipt({ hash: fundHash });

  console.log(`✅ Market Funded!`);
  console.log(`Explorer: https://testnet.arcscan.app/address/${receipt.contractAddress}`);
}

deploy().catch(console.error);

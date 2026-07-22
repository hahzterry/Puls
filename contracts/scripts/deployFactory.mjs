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

  const artifactPath = path.resolve('./out/LMSRMarketFactory.sol/LMSRMarketFactory.json');
  if (!fs.existsSync(artifactPath)) {
    console.error('❌ Artifact not found. Please run `forge build` first.');
    process.exit(1);
  }

  const artifact = JSON.parse(fs.readFileSync(artifactPath, 'utf-8'));
  const ABI = artifact.abi;
  const BYTECODE = artifact.bytecode.object;

  console.log(`Deploying LMSRMarketFactory from: ${account.address}`);
  console.log(`Chain: Arc Testnet (5042002)`);

  const hash = await walletClient.deployContract({
    abi: ABI,
    bytecode: BYTECODE.startsWith('0x') ? BYTECODE : `0x${BYTECODE}`,
    args: [USDC],
    gas: 10_000_000n,
  });

  console.log(`Tx: ${hash}`);
  const receipt = await publicClient.waitForTransactionReceipt({ hash });
  console.log(`\n✅ LMSRMarketFactory deployed: ${receipt.contractAddress}`);
  console.log(`Explorer: https://testnet.arcscan.app/address/${receipt.contractAddress}`);

  const deploymentsDir = path.resolve('./deployments');
  if (!fs.existsSync(deploymentsDir)) {
    fs.mkdirSync(deploymentsDir, { recursive: true });
  }

  const config = { factoryAddress: receipt.contractAddress };
  fs.writeFileSync(path.join(deploymentsDir, 'deployed-factory.json'), JSON.stringify(config, null, 2));
}

deploy().catch(console.error);

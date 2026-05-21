import fs from 'fs';
import 'dotenv/config';
import { createWalletClient, createPublicClient, http } from 'viem';
import { privateKeyToAccount } from 'viem/accounts';
import { arcTestnet } from 'viem/chains';

const USDC = '0x3600000000000000000000000000000000000000';

async function deploy() {
  const pk = process.env.PRIVATE_KEY;
  if (!pk) {
    console.error('❌ Set PRIVATE_KEY in .env');
    process.exit(1);
  }

  const account = privateKeyToAccount(pk);
  const walletClient = createWalletClient({ account, chain: arcTestnet, transport: http() });
  const publicClient = createPublicClient({ chain: arcTestnet, transport: http() });

  // Read artifact from Forge output
  const artifact = JSON.parse(fs.readFileSync('./out/LMSRMarketFactory.sol/LMSRMarketFactory.json', 'utf-8'));
  const ABI = artifact.abi;
  const BYTECODE = artifact.bytecode.object;

  console.log(`Deploying LMSRMarketFactory from: ${account.address}`);
  console.log(`Chain: Arc Testnet (5042002)`);

  const hash = await walletClient.deployContract({
    abi: ABI,
    bytecode: BYTECODE.startsWith('0x') ? BYTECODE : `0x${BYTECODE}`,
    args: [USDC],
  });

  console.log(`Tx: ${hash}`);
  const receipt = await publicClient.waitForTransactionReceipt({ hash });
  console.log(`\n✅ LMSRMarketFactory deployed: ${receipt.contractAddress}`);
  console.log(`Explorer: https://testnet.arcscan.app/address/${receipt.contractAddress}`);

  // Approve factory contract to spend owner USDC
  console.log(`Approving factory to spend USDC...`);
  const approveHash = await walletClient.writeContract({
    address: USDC,
    abi: [
      {
        name: 'approve',
        type: 'function',
        stateMutability: 'nonpayable',
        inputs: [
          { name: 'spender', type: 'address' },
          { name: 'amount', type: 'uint256' },
        ],
        outputs: [{ name: '', type: 'bool' }],
      },
    ],
    functionName: 'approve',
    args: [receipt.contractAddress, 115792089237316195423570985008687907853269984665640564039457584007913129639935n], // max uint256
  });
  console.log(`Approve Tx: ${approveHash}`);
  await publicClient.waitForTransactionReceipt({ hash: approveHash });
  console.log(`✅ Approved factory to spend USDC`);
  
  // Save to config file
  const config = { factoryAddress: receipt.contractAddress };
  fs.writeFileSync('./deployed-factory.json', JSON.stringify(config, null, 2));
}

deploy().catch(console.error);

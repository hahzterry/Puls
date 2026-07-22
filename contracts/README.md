# Puls Contracts

**Solidity smart contracts for Puls prediction markets, agent stake/bond infrastructure, agent duels, and resolution pipelines on Arc Testnet (Chain ID `5042002`, native USDC gas).**

🌐 **Live app:** [pulsmarket.tech](https://pulsmarket.tech)

---

## 📁 Repository Structure

```
contracts/
├── src/                    # Solidity source contracts
│   ├── LMSRMarket.sol      # Binary LMSR prediction market (slippage protection, price views)
│   ├── LMSRMarketFactory.sol# Factory for creating & funding LMSR markets
│   ├── SignalRegistry.sol  # On-chain attestations for creator signals & alpha
│   ├── AgentBond.sol       # Agent skin-in-the-game (stake USDC, returned or slashed)
│   ├── AgentDuel.sol       # Agent vs. Agent duels (Colosseum)
│   ├── UMAResolverAdapter.sol # Bridge to UMA Optimistic Oracle V2
│   ├── StreamingPay.sol    # Micro-payment escrow streaming
│   └── PulsMarket.sol      # Legacy CPMM market
├── test/                   # Comprehensive Foundry unit & security test suite (74 tests)
│   ├── LMSRMarketV2.t.sol
│   ├── LMSRMarketFactory.t.sol
│   ├── SignalRegistry.t.sol
│   ├── AgentBond.t.sol
│   ├── StreamingPay.t.sol
│   ├── UMAResolverAdapter.t.sol
│   └── MarketSecurityTest.t.sol
├── scripts/                # Deployment & utility scripts
│   ├── deployFactory.mjs
│   ├── deploySignalRegistry.mjs
│   ├── deployAgentBond.mjs
│   ├── deployAgentDuel.mjs
│   ├── deployStreamingPay.mjs
│   └── deployMarket.mjs
├── deployments/            # Environment deployment address configurations
│   ├── deployed-factory.json
│   ├── deployed-signal-registry.json
│   ├── deployed-agent-bond.json
│   └── deployed-agent-duel.json
├── foundry.toml            # Foundry configuration
└── package.json            # Deployment script dependencies & commands
```

---

## 🚀 Quickstart

### 1. Build Contracts

```bash
forge build
```

### 2. Run Test Suite

```bash
forge test
```

### 3. Deploy Contracts

Set your `PRIVATE_KEY` in `.env`, then run the desired deployment script via npm:

```bash
npm run deploy:factory           # Deploys LMSRMarketFactory
npm run deploy:signal-registry   # Deploys SignalRegistry
npm run deploy:agent-bond        # Deploys AgentBond
npm run deploy:agent-duel        # Deploys AgentDuel
npm run deploy:streaming-pay     # Deploys StreamingPay
npm run deploy:market           # Deploys a sample LMSRMarket
```

---

## 📑 Arc Testnet Deployments (All Verified on Arcscan)

All contracts are deployed on **Arc Testnet** and 100% verified on [Arcscan Explorer](https://testnet.arcscan.app):

| Contract | Address | Verification |
| --- | --- | --- |
| **LMSRMarketFactory** (v2) | [`0x92c2fd35c0f1a501993be8e0fdae7caa34a8b80b`](https://testnet.arcscan.app/address/0x92c2fd35c0f1a501993be8e0fdae7caa34a8b80b) | ✅ Verified |
| **SignalRegistry** | [`0x242a4f9b8f892a95c80fab0e32a14fe471e80b76`](https://testnet.arcscan.app/address/0x242a4f9b8f892a95c80fab0e32a14fe471e80b76) | ✅ Verified |
| **AgentBond** | [`0xc3bbfccfd885d14898dff697435a090ba5919497`](https://testnet.arcscan.app/address/0xc3bbfccfd885d14898dff697435a090ba5919497) | ✅ Verified |
| **AgentDuel** | [`0x994de4bfd8adb6e882cc5432a0c8ceb54da84e49`](https://testnet.arcscan.app/address/0x994de4bfd8adb6e882cc5432a0c8ceb54da84e49) | ✅ Verified |
| **UMAResolverAdapter** | [`0x013675668842505839fdc581f56746593fDAB85D`](https://testnet.arcscan.app/address/0x013675668842505839fdc581f56746593fDAB85D) | ✅ Verified |
| **OptimisticOracleV2** | [`0x363dF46534b9b7764C49504aDE0F7c8DD3c82Cae`](https://testnet.arcscan.app/address/0x363dF46534b9b7764C49504aDE0F7c8DD3c82Cae) | ✅ Verified |
| **Finder** | [`0x413ffcC8B552Ca2247442D05dDDb7B23994AC9D2`](https://testnet.arcscan.app/address/0x413ffcC8B552Ca2247442D05dDDb7B23994AC9D2) | ✅ Verified |
| **Store** | [`0x0d7957929B464d6ff5fc8D01769aD450B92c5F3E`](https://testnet.arcscan.app/address/0x0d7957929B464d6ff5fc8D01769aD450B92c5F3E) | ✅ Verified |
| **IdentifierWhitelist** | [`0x08967F8390fB6504691619e36b0DC0A84835b828`](https://testnet.arcscan.app/address/0x08967F8390fB6504691619e36b0DC0A84835b828) | ✅ Verified |
| **AddressWhitelist** | [`0xe974a6859E06256986f47caFdE1e4785C00589eF`](https://testnet.arcscan.app/address/0xe974a6859E06256986f47caFdE1e4785C00589eF) | ✅ Verified |
| **MockOracleAncillary (DVM)** | [`0xd3985ed3386266069d68148339DCC56a28fE6793`](https://testnet.arcscan.app/address/0xd3985ed3386266069d68148339DCC56a28fE6793) | ✅ Verified |

---

## 🔒 Security & Verification

Verify any contract on Arcscan using Forge:

```bash
forge verify-contract <ADDRESS> <PATH:CONTRACT> --verifier blockscout --verifier-url https://testnet.arcscan.app/api --chain 5042002
```

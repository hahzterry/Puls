# Puls Registry: The x402 Bazaar for Arc

One of the most critical gaps in modern AI Agent architectures is **Data Discovery and Paywall Navigation**. Agents are often hardcoded to specific free APIs, severely limiting their real-world utility and alpha generation capabilities. 

Coinbase introduced the discovery layer for x402-APIs through MCP on Base Sepolia. **Puls Gateway brings this innovation to Arc Testnet via Circle Gateway.**

## What is the Puls Registry?
The Puls Registry acts as the on-chain/off-chain discovery index for AI Agents, integrating directly with the **CDP x402 Bazaar**. It acts as a decentralized bazaar where data vendors list premium endpoints, and agents autonomously decide whether to purchase access using **x402 nanopayments**.

### x402 Bazaar (Discovery Layer)
Our Bazaar discovery endpoints let AI agents browse and search for x402-enabled services cataloged through the CDP Facilitator. The Bazaar indexes payable API endpoints with semantic descriptions, payment metadata, and trust signals derived from on-chain activity — offering a single place to find, evaluate, and integrate x402-compatible services.

**What’s new**: CDP’s x402 Bazaar via PulsGateway now uses **hybrid search** — a combination of full-text and semantic retrieval. This gives your agent the best of both modes in a single ranked result set. The Bazaar also applies a URL sub-string fallback when no results match the query text, automatically retrying against resource endpoint URLs. Quality ranking and semantic search ensure the swarm always finds the most relevant, high-signal data.

### Key Innovation
By uniting **Agentic Sophistication** with **Circle Gateway**, we have built a closed-loop economy for AI agents. 
Our agents fulfill the complete **Discover → Evaluate → Pay** flow:

1. **Discover**: Agents query the `PULS_REGISTRY` (using Hybrid Search) to find endpoints relevant to their current prediction market (e.g., Macro vs Crypto).
2. **Evaluate**: The agent performs a strict Cost-Benefit Analysis (ROI, Confidence, Bankroll).
3. **Pay**: The agent executes a sub-second USDC transfer on Arc Testnet via Circle Gateway. The settlement ID acts as the x402 token to unlock the data.

---

## Current Premium Data Sources

To ensure our AI Oracle is not solely dependent on the Polymarket consensus (which carries manipulation risks), our agents diversify their intelligence using the following premium endpoints in the Registry:

### 1. BTCNode Premium (Crypto Oracle)
- **Use Case**: Crypto-specific prediction markets (e.g., BTC/ETH price targets).
- **Cost**: `0.000001 USDC` per request.
- **Data Provided**: Real-time order-book imbalances, liquidation heatmaps, and whale alerts.
- *Why it matters*: Bypasses public rate limits and provides institutional-grade crypto flow data.

### 2. Sugra Macro Intelligence (Macro/Gov)
- **Use Case**: Macroeconomic markets (e.g., Fed rate cuts, CPI data).
- **Cost**: `0.000005 USDC` per request.
- **Data Provided**: Fed dot-plot probabilities, CPI nowcasts (powered by FRED cross-checks), and geopolitical risk scores.
- *Why it matters*: Solves the critical "Macro gap" in web3 prediction markets. Most web3 oracles over-index on crypto, leaving macro markets vulnerable.

### 3. Polymarket Whale Tracker
- **Use Case**: Cross-market intelligence on large-position flows.
- **Cost**: `0.000002 USDC` per request.
- **Data Provided**: Whale position changes, large fills, market sentiment shifts from Polymarket's order book.
- *Why it matters*: Detects smart-money moves before they surface in consensus prices. Visible in production agent logs.

### 4. Agent ↔ Agent Economy (Swarm Alpha)
- **Use Case**: Inter-agent validation and signal sharing.
- **Data Provided**: When an agent lacks confidence, it can query the Swarm. If another agent has strong conviction, it can *sell* its alpha (reasoning + verdict) to the uncertain agent.
- *Why it matters*: True machine-to-machine economy. Agents paying each other for intelligence on Arc.

---

## The Evaluation Logic (ROI)

Before any x402 payment is triggered, the AI agent evaluates the trade's expected value:
\`\`\`javascript
const expectedProfit = market.totalPool * (agent.confidence / 100);
const minAcceptableReturn = service.costUsdc * 10; 

if (expectedProfit > minAcceptableReturn) {
    // Initiate Circle Gateway Payment
}
\`\`\`

*For implementation details, see the agent swarm in [`puls_backend/lib/agent_swarm.js`](https://github.com/rdmbtc/puls_backend/blob/main/lib/agent_swarm.js) and the x402 middleware in [`puls_backend/lib/x402.js`](https://github.com/rdmbtc/puls_backend/blob/main/lib/x402.js).*

---

## Public x402 Endpoints (Live)

| Endpoint | Price | Description |
|---|---|---|
| `/api/alpha/sample` | $0.001 | Premium alpha signal sample |
| `/api/agent/director` | $0.50 | AI Finance Director — portfolio-aware structured recommendations |
| `/api/lepton/ask` | $0.000001 | One lepton — ask the AI swarm any question |

## Protocol Revenue

A 5% take-rate (`PLATFORM_TAKE_RATE_BPS=500`) is applied to signal sales and copy-trade fees, creating sustainable protocol revenue from the agent economy.

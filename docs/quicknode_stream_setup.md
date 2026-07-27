# QuickNode Stream & Webhook Setup Guide

Follow these steps to configure a Stream in your QuickNode dashboard to send real-time on-chain events to the Puls backend.

## Step 1: Create a Stream

1. Log in to your **QuickNode Dashboard**.
2. Navigate to **Streams** from the sidebar and click **Create Stream**.
3. Set the **Chain** to **Arc Testnet**.
4. Set the **Network** to **Arc Testnet**.
5. Choose **Receipt Logs** as the dataset.

## Step 2: Configure Stream Rule (Filter)

To capture events across all dynamically deployed markets while ignoring unrelated contracts, we set up a topic-based filter.

1. Under the **Stream Rule** or **Filter** section, select **Custom Filter** or enter a JSON filter rule.
2. We want to match events where `topic0` (the event signature hash) is one of our four target market events:
   - `Bought`: `0x522b9472f4bf5c3e704f38993116a9a181d51f250d5fe03cc67c4c26acfe1c25`
   - `Sold`: `0x3d18418a1901dcb4925e7c211b7db7022d68152e5ba705b0f7197d9c4c8e744b`
   - `Resolved`: `0xdabf623a6bec72ad159e2d9533e7149ec45bfc657e39f49fb6a9509852dc77dc`
   - `Claimed`: `0xd8138f8a3f377c5259ca548e70e4c2de94f129f5a11036a15b69513cba2b426a`

Example JSON filter matching any of these signatures:
```json
{
  "topics": [
    [
      "0x522b9472f4bf5c3e704f38993116a9a181d51f250d5fe03cc67c4c26acfe1c25",
      "0x3d18418a1901dcb4925e7c211b7db7022d68152e5ba705b0f7197d9c4c8e744b",
      "0xdabf623a6bec72ad159e2d9533e7149ec45bfc657e39f49fb6a9509852dc77dc",
      "0xd8138f8a3f377c5259ca548e70e4c2de94f129f5a11036a15b69513cba2b426a"
    ]
  ]
}
```

*Note: Leaving the target `address` filter empty ensures that when new prediction market contracts are deployed dynamically, their events are immediately matched without needing to manually update the stream config!*

## Step 3: Configure Webhook Destination

1. Choose **Webhook** as the destination type.
2. In the **Webhook URL** field, enter:
   ```
   https://84-22-148-57.sslip.io/api/webhook/quicknode?secret=YOUR_SECRET_TOKEN
   ```
   *(Replace `YOUR_SECRET_TOKEN` with a secure random string of your choice).*
3. Under **Headers**, add a custom header:
   - Key: `x-qn-secret`
   - Value: `YOUR_SECRET_TOKEN`
4. Set the **QUICKNODE_WEBHOOK_SECRET** environment variable on your VPS to match this token. This ensures only QuickNode can post to this endpoint.

## Step 4: Activate Stream

1. Run a test payload using the **Test Stream** button to verify connectivity.
2. Click **Create Stream** to activate it.
3. On-chain events will now be pushed to your backend in real-time!

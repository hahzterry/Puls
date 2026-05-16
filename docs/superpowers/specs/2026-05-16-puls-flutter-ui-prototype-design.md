# Puls Flutter UI Prototype Design

## Summary

Puls is a Flutter Android UI prototype for a premium prediction-market app. It is inspired by the broad category of prediction markets, but it uses original Puls branding, original layouts, and mock data only. The first build is not a real trading product: it has no backend, no real authentication, no wallet, and no real-money actions.

The core differentiator is Puls Feed, a TikTok-style vertical prediction stream where users can quickly inspect markets and choose Yes or No in a Tinder-like interaction. Choosing a side opens a fake trade preview instead of placing an actual order.

## Goals

- Create a polished Android-first Flutter prototype.
- Make Puls Feed the main home screen and strongest first impression.
- Include discovery, market detail, fake trade preview, portfolio, watchlist, alerts, and profile surfaces.
- Use realistic mock data so the app feels credible in demos.
- Keep the code structured like an MVP foundation so mock repositories can later be replaced with real APIs.

## Non-Goals

- No real trading, order placement, settlement, deposits, withdrawals, or wallet integration.
- No production authentication.
- No backend service.
- No compliance, KYC, or real-money prediction-market operations.
- No exact copy of Polymarket screens, branding, copy, or visual identity.

## Product Scope

The prototype includes:

- Light onboarding with Puls branding and a fake continue action.
- Home: Puls Feed, a full-screen vertical stream of prediction markets.
- Fast Yes/No reactions on each feed item.
- Fake trade preview after choosing Yes or No.
- Discover screen for categories, trending markets, search, and filters.
- Market detail screen with odds, chart, activity, comments, and news.
- Portfolio screen with mock positions, P&L, and history.
- Watchlist and alerts screen with saved markets and fake alert states.
- Profile/settings screen with demo account details and app preferences.

The highest polish goes into Puls Feed and the Market Detail / Trade Preview flow.

## User Experience

The first meaningful app screen after onboarding is Puls Feed. Each feed item should feel like a focused market briefing:

- Market question.
- Yes and No prices or implied probabilities.
- Short context summary.
- Volume, liquidity, or activity indicator.
- Deadline or resolution date.
- Trend movement since the previous period.
- Watchlist/save action.
- Entry point into full market detail.

Users scroll vertically to move through predictions. They can choose Yes or No using large thumb-friendly actions fixed near the lower part of the screen. After selection, the app opens a trade preview sheet showing selected side, mock amount, estimated payout, and a clear demo-only message.

Discover remains a more deliberate browsing surface. Portfolio and Watchlist use compact dashboard-style layouts for scanning.

## Visual Direction

Puls uses a premium fintech dark style:

- Deep charcoal and layered black surfaces.
- Strong white text hierarchy.
- Green or teal for Yes, positive movement, and bullish states.
- Red or coral for No, negative movement, and bearish states.
- Electric blue as the Puls brand accent and focus color.
- Thin borders, restrained shadows, tight spacing, and cards with 8px radius or less.
- Dense financial information where useful, balanced with readable full-screen feed cards.

The design should feel fast, credible, and market-native rather than like a generic social feed.

## Architecture

The Flutter code should be organized by feature boundaries:

- `app`: routing, app shell, navigation, and startup flow.
- `core`: theme, typography, spacing, mock utilities, and shared widgets.
- `data`: mock market data, fake portfolio data, fake activity, comments, news, and alerts.
- `features/onboarding`: intro screens and fake continue flow.
- `features/feed`: Puls Feed, prediction cards, Yes/No interaction, and feed state.
- `features/discover`: categories, trending markets, search, and filter UI.
- `features/market`: market detail, chart display, and trade preview.
- `features/portfolio`: positions, P&L, and history.
- `features/watchlist`: saved markets and fake alerts.
- `features/profile`: settings and demo account surfaces.

State is local and mock-driven, but shaped like a future real app. UI should read from repositories/controllers rather than hardcoded widget lists. Future real data should be possible by replacing mock repositories with API-backed repositories.

## Navigation

The app uses bottom navigation:

1. Feed
2. Discover
3. Portfolio
4. Watchlist
5. Profile

Market detail opens from Feed, Discover, Portfolio, or Watchlist. Trade preview opens as a bottom sheet or pushed overlay from feed cards and market detail.

## Data Flow

- Mock repositories provide markets, feed items, categories, comments/news, positions, and alerts.
- Feed and screens consume local state through controllers/providers.
- Yes/No selections update local mock state for selected side and preview values.
- Watchlist toggles update in-memory state for the current session.
- Portfolio may show mock positions by default and may optionally add fake positions after a confirmed demo trade.
- No persistence is required in the first prototype.

## Error And Empty States

The prototype should include:

- Empty portfolio state for no positions.
- Empty watchlist state.
- Lightweight mock loading states where they improve perceived quality.
- Trade preview validation for invalid or missing amount.
- Clear demo-only wording in trade preview and profile/account surfaces.

## Testing

Testing should cover:

- Feed card widget rendering.
- Yes/No selection opening the trade preview.
- Bottom navigation between major tabs.
- Market detail rendering with mock data.
- Unit tests for trade preview and estimated payout helper calculations.

Manual verification should include an Android run check for vertical feed smoothness, responsive layout, readable typography, and no overlapping text.

## Implementation Notes

The first implementation should optimize for a strong demo experience while keeping feature boundaries clean. The app should not include backend setup or real integrations until a later spec defines those requirements.

// /m/<slug> share endpoint — serves per-market Open Graph tags to link
// scrapers (Twitter/X, Telegram, Discord, Slack, WhatsApp…) and instantly
// redirects humans into the app at /?m=<slug>.
//
// Zero dependencies — runs on the default Vercel Node runtime.

const SITE = 'https://app.pulsmarket.tech';
const BACKEND = 'https://api.pulsmarket.tech';
const FALLBACK_IMAGE = `${SITE}/og-image.png`;

function esc(s) {
  return String(s == null ? '' : s)
    .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
}

async function fetchJson(url, ms = 3500) {
  const ctrl = new AbortController();
  const t = setTimeout(() => ctrl.abort(), ms);
  try {
    const r = await fetch(url, { signal: ctrl.signal, headers: { Accept: 'application/json' } });
    if (!r.ok) return null;
    return await r.json();
  } catch {
    return null;
  } finally {
    clearTimeout(t);
  }
}

function pct(p) {
  const n = Number(p);
  return Number.isFinite(n) ? `${Math.round(n * 100)}¢` : null;
}

async function getMarket(slug) {
  // 1) Polymarket gamma (real markets — has question, prices, image)
  const list = await fetchJson(`https://gamma-api.polymarket.com/markets?slug=${encodeURIComponent(slug)}`);
  if (Array.isArray(list) && list.length > 0) {
    const m = list[0];
    let prices = [];
    try { prices = JSON.parse(m.outcomePrices || '[]'); } catch {}
    return {
      question: m.question || slug,
      yes: pct(m.yesPrice ?? prices[0]),
      no: pct(m.noPrice ?? prices[1]),
      image: m.image || m.icon || null,
    };
  }
  // 2) Puls backend (custom / user-created markets)
  const info = await fetchJson(`${BACKEND}/api/market/info?slug=${encodeURIComponent(slug)}`);
  if (info && !info.error) {
    return {
      question: info.question && info.question !== slug
        ? info.question
        : slug.replace(/-/g, ' ').replace(/\b\w/g, (c) => c.toUpperCase()),
      yes: pct(info.yesPrice),
      no: pct(info.noPrice),
      image: null,
    };
  }
  return null;
}

module.exports = async (req, res) => {
  const rawSlug = String(req.query.slug || '').trim();
  let slug = rawSlug.toLowerCase();
  try { slug = decodeURIComponent(rawSlug).trim().toLowerCase(); } catch (_) {}
  // Slugs are url-safe by construction; reject empty or invalid format.
  if (!slug || !/^[a-z0-9_%.-]{1,500}$/.test(slug)) {
    res.statusCode = 302;
    res.setHeader('Location', '/');
    return res.end();
  }

  // On app.pulsmarket.tech we STILL serve full SEO HTML (200, not 302) so
  // search engines index each /m/<slug> as its own rich page. Humans are sent
  // into the Flutter app via a soft JS redirect (+ noscript fallback) to
  // /?m=<slug>. (Removing the old 302 is what made markets indexable again —
  // a 302 to /?m= just collapses every market into the single homepage.)

  const m = await getMarket(slug);
  const title = m ? `${m.question} — Puls` : 'Puls — The Market for What Happens Next';
  const odds = m && m.yes && m.no ? `YES ${m.yes} · NO ${m.no} — ` : '';
  const description = `${odds}Trade this prediction with USDC on Arc. Sign in with Google, get a wallet instantly, no seed phrase.`;
  const image = (m && m.image) || FALLBACK_IMAGE;
  const target = `${SITE}/?m=${encodeURIComponent(slug)}`;
  const canonical = `${SITE}/m/${encodeURIComponent(slug)}`;

  const html = `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>${esc(title)}</title>
<meta name="description" content="${esc(description)}">
<meta name="robots" content="index, follow, max-image-preview:large">
<link rel="canonical" href="${esc(canonical)}">
<meta property="og:type" content="website">
<meta property="og:site_name" content="Puls">
<meta property="og:url" content="${esc(canonical)}">
<meta property="og:title" content="${esc(title)}">
<meta property="og:description" content="${esc(description)}">
<meta property="og:image" content="${esc(image)}">
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:title" content="${esc(title)}">
<meta name="twitter:description" content="${esc(description)}">
<meta name="twitter:image" content="${esc(image)}">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<script>location.replace(${JSON.stringify(target)});</script>
<noscript><meta http-equiv="refresh" content="0;url=${esc(target)}"></noscript>
</head>
<body style="font-family:system-ui,-apple-system,'Segoe UI',Roboto,sans-serif;background:#0A0E1A;color:#EAF0FF;margin:0;line-height:1.6">
<div style="max-width:640px;margin:0 auto;padding:48px 24px">
  <p style="letter-spacing:2px;font-size:12px;color:#F472B6;font-weight:700">PULS · PREDICTION MARKET ON ARC</p>
  <h1 style="font-size:30px;line-height:1.2;margin:14px 0">${esc(title)}</h1>
  ${m && m.yes && m.no ? `<p style="font-size:20px;color:#2DD4BF;font-weight:700">YES ${m.yes} · NO ${m.no}</p>` : ''}
  <p style="color:#9AA6C0">Swipe to trade this market in USDC on Arc Network — sign in with Google, no seed phrase, sub-second settlement. AI agents trade alongside you with real USDC staked on every call.</p>
  <p><a href="${esc(target)}" style="color:#2DD4BF;font-weight:600">Open market in the Puls app →</a></p>
  <hr style="border:0;border-top:1px solid #1B2236;margin:28px 0">
  <nav style="font-size:13px">
    <a href="https://pulsmarket.tech/" style="color:#9AA6C0;margin-right:14px;text-decoration:none">Puls</a>
    <a href="https://pulsmarket.tech/stats" style="color:#9AA6C0;margin-right:14px;text-decoration:none">Live stats</a>
    <a href="https://pulsmarket.tech/versus" style="color:#9AA6C0;margin-right:14px;text-decoration:none">Humans vs AI</a>
    <a href="https://docs.pulsmarket.tech" style="color:#9AA6C0;text-decoration:none">Docs</a>
  </nav>
</div>
</body>
</html>`;

  res.statusCode = 200;
  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  res.setHeader('Cache-Control', 's-maxage=300, stale-while-revalidate=3600');
  res.end(html);
};

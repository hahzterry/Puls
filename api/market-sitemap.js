// /api/market-sitemap — dynamic sitemap of every tradable Puls market.
// Generates <url> entries for https://app.pulsmarket.tech/m/<slug> so Google
// can discover + index each market page. Pulls the market roster from the
// Puls backend (paginated, 100/page, capped at 2000 URLs for speed).
//
// Zero dependencies — runs on the default Vercel Node runtime.

const SITE = 'https://app.pulsmarket.tech';
const BACKEND = 'https://api.pulsmarket.tech';
const PAGE = 100;
const MAX_URLS = 2000;

function esc(s) {
  return String(s == null ? '' : s)
    .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
}

function iso(s) {
  const d = new Date(s);
  return Number.isNaN(d.getTime()) ? '' : d.toISOString().slice(0, 10);
}

async function fetchMarkets(offset) {
  try {
    const ctrl = new AbortController();
    const t = setTimeout(() => ctrl.abort(), 6000);
    const r = await fetch(
      `${BACKEND}/api/markets?limit=${PAGE}&offset=${offset}`,
      { signal: ctrl.signal, headers: { Accept: 'application/json' } },
    );
    clearTimeout(t);
    if (!r.ok) return [];
    const list = await r.json();
    return Array.isArray(list) ? list : [];
  } catch {
    return [];
  }
}

module.exports = async (req, res) => {
  const urls = [];
  let offset = 0;
  let more = true;

  while (more && urls.length < MAX_URLS) {
    const batch = await fetchMarkets(offset);
    if (batch.length === 0) { more = false; break; }
    for (const m of batch) {
      const slug = String(m.slug || '').trim();
      if (!slug || !/^[a-z0-9_%.-]{1,500}$/.test(slug)) continue;
      urls.push({
        slug,
        lastmod: iso(m.updatedAt || m.createdAt || ''),
      });
    }
    offset += batch.length;
    if (batch.length < PAGE) more = false;
  }

  const entries = urls
    .map((u) => {
      const lm = u.lastmod ? `\n    <lastmod>${esc(u.lastmod)}</lastmod>` : '';
      return `  <url>\n    <loc>${SITE}/m/${esc(u.slug)}</loc>${lm}\n    <changefreq>daily</changefreq>\n    <priority>0.6</priority>\n  </url>`;
    })
    .join('\n');

  const xml = `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n${entries}\n</urlset>`;

  res.statusCode = 200;
  res.setHeader('Content-Type', 'application/xml; charset=utf-8');
  res.setHeader('Cache-Control', 'public, s-maxage=3600, stale-while-revalidate=86400');
  res.end(xml);
};

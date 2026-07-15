const backendUrl = 'https://api.pulsmarket.tech'; // via Cloudflare (edge cache + Brotli + HTTP/3); origin: https://31-77-204-129.sslip.io
const factoryAddress = '0x92c2fd35c0f1a501993be8e0fdae7caa34a8b80b';
const appBaseUrl = 'https://pulsmarket.tech';
const appUrl = 'https://app.pulsmarket.tech'; // the product lives here; pulsmarket.tech is the landing

String proxifyImageUrl(String url) {
  if (url.isEmpty || url.startsWith(backendUrl) || url.startsWith('assets/') || url.startsWith('http://localhost')) return url;
  return '$backendUrl/api/image-proxy?url=${Uri.encodeComponent(url)}';
}

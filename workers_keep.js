addEventListener('scheduled', event => event.waitUntil(handleScheduled()));
// Works with ProxMe2 Serv00 SSH script or Github/VPS/Router script to generate keep-alive and restart web pages
// Separate each keep-alive/up page or restart/re page with space, comma, or Chinese comma, prefix with http://
const urlString = 'http://keepalive-or-restart-page1 http://keepalive-or-restart-page2 http://keepalive-or-restart-page3 ...';
const urls = urlString.split(/[\s,，]+/);
const TIMEOUT = 5000;
async function fetchWithTimeout(url) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), TIMEOUT);
  try {
    await fetch(url, { signal: controller.signal });
    console.log(`Success: ${url}`);
  } catch (error) {
    console.warn(`Failed: ${url}, Error: ${error.message}`);
  } finally {
    clearTimeout(timeout);
  }
}
async function handleScheduled() {
  console.log('Task started');
  await Promise.all(urls.map(fetchWithTimeout));
  console.log('Task completed');
}

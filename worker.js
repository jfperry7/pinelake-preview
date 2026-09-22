/**
 * Worker entry point.
 *
 * Cloudflare's "Connect to Git" flow now creates a Worker with static assets
 * rather than a Pages project, and a Worker does not pick up the Pages
 * `functions/` directory convention. This routes the one dynamic path to the
 * inquiry handler and hands everything else to the static asset server.
 */

import { onRequest as inquiry } from './functions/api/inquiry.js';

/**
 * The live public site. Every other hostname this Worker answers on - the
 * .workers.dev staging URL, any preview alias - is a staging surface serving
 * the same deployment, so it must never reach a search index.
 *
 * This is done here rather than as a switch in `_headers` and `robots.txt`
 * because one deployment serves both staging and live: a blanket rule that is
 * correct for staging is wrong for the real domain the moment it launches,
 * and removing it exposes staging as duplicate content against the club's own
 * site. Guarding by hostname is right in both places at once, with nothing
 * left for anyone to remember to flip. Same approach as the GA4 guard in the
 * page head.
 */
const LIVE_HOSTS = new Set(['pinelakecc.com', 'www.pinelakecc.com']);

const STAGING_ROBOTS = 'User-agent: *\nDisallow: /\n';

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);

    // Plain http never serves a page. 301 to https before anything else, so
    // this holds even if the zone-level "Always Use HTTPS" toggle is off.
    if (url.protocol === 'http:') {
      url.protocol = 'https:';
      return Response.redirect(url.toString(), 301);
    }

    if (url.pathname === '/api/inquiry') {
      return inquiry({ request, env, ctx });
    }

    const staging = !LIVE_HOSTS.has(url.hostname);

    // The robots.txt in the repo is the live one. Staging gets its own.
    if (staging && url.pathname === '/robots.txt') {
      return new Response(STAGING_ROBOTS, {
        headers: {
          'Content-Type': 'text/plain; charset=utf-8',
          'X-Robots-Tag': 'noindex, nofollow',
          'Cache-Control': 'no-store'
        }
      });
    }

    // Video: neither the asset server nor the ASSETS binding honours Range
    // requests (measured 22 Sept - every asset answers 200 with the whole
    // file). Without 206 support iOS Safari will not play the hero at all and
    // Chrome re-downloads the 7 MB file several times per page load. So byte
    // ranges for .mp4 are served here. wrangler.jsonc routes .mp4 through the
    // Worker for exactly this reason while leaving images native.
    if (/\.mp4$/i.test(url.pathname)) {
      const ranged = await serveVideoRange(request, env);
      if (ranged) return staging ? tagNoindex(ranged) : ranged;
    }

    // Everything else is a static file. ASSETS applies _redirects and
    // _headers before serving, so the 59 old-URL redirects keep working.
    const response = await env.ASSETS.fetch(request);
    return staging ? tagNoindex(response) : response;
  }
};

/**
 * Staging only: mark a response noindex. 204 and 304 carry no body and cannot
 * be rebuilt through the Response constructor; they are replies to a request
 * that already carried the header, so there is nothing to protect.
 */
function tagNoindex(response) {
  if (response.status === 204 || response.status === 304) return response;
  const tagged = new Response(response.body, response);
  tagged.headers.set('X-Robots-Tag', 'noindex, nofollow');
  return tagged;
}

/**
 * Byte-range support for video.
 *
 * Handles the single-range forms browsers actually send - bytes=a-b, bytes=a-,
 * bytes=-n. With no Range header the asset is returned whole but with
 * Accept-Ranges set, so the browser asks for ranges on its next request
 * instead of re-downloading.
 *
 * The ASSETS binding's response carries NO Content-Length inside the Worker
 * (the edge adds it on the way out), and Number(null) is 0, not NaN - the
 * first deploy of this turned every range into a 416 with a Content-Range total
 * of 0 for exactly that reason. So the length is parsed defensively, and when the size
 * is unknown the body is read once and sliced directly. That is 7 MB in memory
 * per range request, well inside the Worker's limits, and the edge caches the
 * binding fetch. When a length IS known the slice is streamed instead.
 *
 * Returns null if the asset cannot be fetched (caller falls through to the
 * normal path, which will 404), and 416 for an unsatisfiable range.
 */
async function serveVideoRange(request, env) {
  const full = await env.ASSETS.fetch(new Request(request.url, { method: 'GET' }));
  if (!full.ok || !full.body) return null;

  const headers = new Headers(full.headers);
  headers.set('Accept-Ranges', 'bytes');
  headers.delete('Content-Encoding');

  const rangeHeader = request.headers.get('Range');
  const isHead = request.method === 'HEAD';

  if (!rangeHeader) {
    if (isHead) { await full.body.cancel(); return new Response(null, { status: 200, headers }); }
    return new Response(full.body, { status: 200, headers });
  }

  // Known length -> stream the slice. Unknown -> buffer once, then slice.
  const lengthHeader = full.headers.get('Content-Length');
  let total = lengthHeader === null || lengthHeader === '' ? NaN : Number(lengthHeader);
  let buffered = null;
  if (!(total > 0)) {
    buffered = new Uint8Array(await full.arrayBuffer());
    total = buffered.byteLength;
  }

  const m = /^bytes=(\d*)-(\d*)$/.exec(rangeHeader.trim());
  let start = NaN, end = NaN;
  if (m && m[1] !== '') {
    start = Number(m[1]);
    end = m[2] !== '' ? Math.min(Number(m[2]), total - 1) : total - 1;
  } else if (m && m[2] !== '') {
    const n = Math.min(Number(m[2]), total);
    start = total - n;
    end = total - 1;
  }
  if (!m || !(start >= 0) || !(start <= end) || start >= total) {
    if (!buffered) await full.body.cancel();
    return new Response(null, {
      status: 416,
      headers: { 'Content-Range': 'bytes */' + total, 'Accept-Ranges': 'bytes' }
    });
  }

  const length = end - start + 1;
  headers.set('Content-Range', 'bytes ' + start + '-' + end + '/' + total);
  headers.set('Content-Length', String(length));

  if (isHead) { if (!buffered) await full.body.cancel(); return new Response(null, { status: 206, headers }); }

  if (buffered) {
    return new Response(buffered.subarray(start, end + 1), { status: 206, headers });
  }

  // Streaming path: skip `start` bytes, pass `length` bytes, then stop.
  let skipped = 0;
  let sent = 0;
  const slicer = new TransformStream({
    transform(chunk, controller) {
      let c = chunk;
      if (skipped < start) {
        const need = start - skipped;
        if (c.byteLength <= need) { skipped += c.byteLength; return; }
        c = c.subarray(need);
        skipped = start;
      }
      const remaining = length - sent;
      if (c.byteLength > remaining) c = c.subarray(0, remaining);
      if (c.byteLength) { controller.enqueue(c); sent += c.byteLength; }
      if (sent >= length) controller.terminate();
    }
  });
  full.body.pipeTo(slicer.writable).catch(function () { /* source closed early on terminate - expected */ });
  return new Response(slicer.readable, { status: 206, headers });
}

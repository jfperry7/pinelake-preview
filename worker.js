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

    // Everything else is a static file. ASSETS applies _redirects and
    // _headers before serving, so the 59 old-URL redirects keep working.
    const response = await env.ASSETS.fetch(request);

    if (!staging) return response;

    // 204 and 304 carry no body and cannot be rebuilt through the Response
    // constructor. They are conditional or empty replies to a request that
    // already carried the header, so there is nothing to protect.
    if (response.status === 204 || response.status === 304) return response;

    const tagged = new Response(response.body, response);
    tagged.headers.set('X-Robots-Tag', 'noindex, nofollow');
    return tagged;
  }
};

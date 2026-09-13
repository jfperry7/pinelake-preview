/**
 * Worker entry point.
 *
 * Cloudflare's "Connect to Git" flow now creates a Worker with static assets
 * rather than a Pages project, and a Worker does not pick up the Pages
 * `functions/` directory convention. This routes the one dynamic path to the
 * inquiry handler and hands everything else to the static asset server.
 */

import { onRequest as inquiry } from './functions/api/inquiry.js';

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);

    if (url.pathname === '/api/inquiry') {
      return inquiry({ request, env, ctx });
    }

    // Everything else is a static file. ASSETS applies _redirects and
    // _headers before serving, so the 59 old-URL redirects keep working.
    return env.ASSETS.fetch(request);
  }
};

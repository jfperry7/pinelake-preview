/**
 * POST /api/inquiry - the contact form handler.
 *
 * Runs on Cloudflare Pages Functions. Validates the submission, decides who
 * at the club should receive it, and sends it through Resend.
 *
 * Environment variables (Pages -> Settings -> Variables and Secrets):
 *   RESEND_API_KEY   secret.  From resend.com/api-keys.
 *   MAIL_FROM        plain.   e.g. "Pine Lake Website <forms@pinelakecc.com>"
 *                             The domain must be verified in Resend.
 *   MAIL_MEMBERSHIP  plain.   melanie@pinelakecc.com
 *   MAIL_EVENTS      plain.   anna@pinelakecc.com
 *   MAIL_ARCHIVE     plain.   optional; BCC'd on everything so the club keeps
 *                             its own record independent of anyone's inbox.
 *   MAIL_TEST_TO     plain.   OPTIONAL TEST SWITCH. While set, every message goes
 *                             to this address instead of the club, and says who
 *                             it would have reached. Delete it to go live.
 *
 * The visitor never chooses the recipient - routing happens here, so a crafted
 * request cannot turn the form into a relay.
 */

var LIMITS = { name: 120, email: 200, phone: 60, interest: 120, message: 4000, page: 120 };

/**
 * Trim, cap length, and replace control characters, which are what a header
 * injection attempt would rely on. Done by character code rather than a regex
 * escape so the source file stays plain ASCII.
 */
function clean(value, max) {
  if (typeof value !== 'string') return '';
  var out = '';
  for (var i = 0; i < value.length && out.length < max; i++) {
    var code = value.charCodeAt(i);
    out += (code < 32 || code === 127) ? ' ' : value.charAt(i);
  }
  return out.trim();
}

/** Deliberately permissive - bounce obvious typos, not unusual valid addresses. */
function looksLikeEmail(value) {
  return /^[^@\s]+@[^@\s.]+\.[^@\s]+$/.test(value);
}

var HTML_ESCAPES = { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' };

function escapeHtml(value) {
  return String(value).replace(/[&<>"']/g, function (c) { return HTML_ESCAPES[c]; });
}

function json(status, body) {
  return new Response(JSON.stringify(body), {
    status: status,
    headers: { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' }
  });
}

export async function onRequestPost(context) {
  var request = context.request;
  var env = context.env;

  var form;
  try {
    var type = request.headers.get('content-type') || '';
    if (type.indexOf('application/json') !== -1) {
      form = await request.json();
    } else {
      form = Object.fromEntries(await request.formData());
    }
  } catch (err) {
    return json(400, { ok: false, error: 'We could not read that submission. Please try again.' });
  }

  // Honeypot: a field hidden from people and irresistible to bots. Accept it
  // quietly rather than erroring, so a bot cannot tell it has been caught.
  if (clean(form.company, 100)) return json(200, { ok: true });

  var name = clean(form.name, LIMITS.name);
  var email = clean(form.email, LIMITS.email);
  var phone = clean(form.phone, LIMITS.phone);
  var interest = clean(form.interest, LIMITS.interest) || 'General inquiry';
  var message = clean(form.message, LIMITS.message);
  var page = clean(form.page, LIMITS.page) || 'the website';

  if (!name) {
    return json(400, { ok: false, error: 'Please add your name so we know who to reply to.' });
  }
  if (!looksLikeEmail(email)) {
    return json(400, { ok: false, error: 'That email address does not look right. Please check it.' });
  }

  // Events and weddings go to catering; everything else to membership.
  var isEvent = /event|wedding|banquet|party|reception|corporate/i.test(interest);
  var intendedTo = isEvent
    ? (env.MAIL_EVENTS || 'anna@pinelakecc.com')
    : (env.MAIL_MEMBERSHIP || 'melanie@pinelakecc.com');

  // Test switch. Resend will only deliver to the account owner's own address
  // until a domain is verified, so this lets the whole path be exercised with
  // no DNS at all. Unset it and mail routes to the club for real.
  var testTo = clean(env.MAIL_TEST_TO, 200);
  var to = testTo || intendedTo;

  var from = env.MAIL_FROM || 'Pine Lake Website <forms@pinelakecc.com>';
  var subject = (testTo ? '[TEST] ' : '') + 'Website inquiry - ' + interest + ' - ' + name;

  var rows = [
    ['Name', name],
    ['Email', email],
    ['Phone', phone || 'not given'],
    ['Interested in', interest],
    ['Sent from', page]
  ];
  if (testTo) rows.push(['Would have gone to', intendedTo]);

  var text = rows.map(function (r) { return r[0] + ': ' + r[1]; }).join('\n');
  if (message) text += '\n\nMessage:\n' + message;

  var html =
    '<div style="font-family:system-ui,-apple-system,sans-serif;font-size:15px;line-height:1.6;color:#1E2B14">'
    + '<p style="margin:0 0 16px"><strong>New inquiry from the Pine Lake website.</strong></p>'
    + '<table style="border-collapse:collapse">'
    + rows.map(function (r) {
        return '<tr><td style="padding:4px 16px 4px 0;color:#6A7263;vertical-align:top">'
             + escapeHtml(r[0])
             + '</td><td style="padding:4px 0">'
             + escapeHtml(r[1])
             + '</td></tr>';
      }).join('')
    + '</table>'
    + (message
        ? '<p style="margin:18px 0 4px;color:#6A7263">Message</p>'
          + '<p style="margin:0;white-space:pre-wrap">' + escapeHtml(message) + '</p>'
        : '')
    + '<p style="margin:22px 0 0;font-size:13px;color:#6A7263">Reply directly to this email to reach them.</p>'
    + '</div>';

  if (!env.RESEND_API_KEY) {
    console.error('inquiry: RESEND_API_KEY is not set');
    return json(500, { ok: false, error: 'The form is not finished being set up. Please call the club on (248) 682-1300.' });
  }

  var payload = {
    from: from,
    to: [to],
    reply_to: email,
    subject: subject,
    text: text,
    html: html
  };
  if (env.MAIL_ARCHIVE && !testTo) payload.bcc = [env.MAIL_ARCHIVE];

  var res;
  try {
    res = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Authorization': 'Bearer ' + env.RESEND_API_KEY,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(payload)
    });
  } catch (err) {
    console.error('inquiry: could not reach Resend', err);
    return json(502, { ok: false, error: 'We could not send that just now. Please try again, or call (248) 682-1300.' });
  }

  if (!res.ok) {
    var detail = '';
    try { detail = await res.text(); } catch (e) {}
    console.error('inquiry: Resend returned ' + res.status + ' ' + detail);
    return json(502, { ok: false, error: 'We could not send that just now. Please try again, or call (248) 682-1300.' });
  }

  return json(200, { ok: true });
}

/** Anything other than POST gets a clear answer rather than a stack trace. */
export async function onRequest(context) {
  if (context.request.method === 'POST') return onRequestPost(context);
  return json(405, { ok: false, error: 'This endpoint accepts form submissions only.' });
}

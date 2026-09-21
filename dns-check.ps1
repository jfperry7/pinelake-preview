<#
  dns-check.ps1 - compare one nameserver's answers against the record
  inventory for pinelakecc.com.

  The nameserver move is the one step of the cutover that can do real damage,
  and the damage is to the club's email, not the website. This checks the
  records by machine instead of by eye, because there are forty of them and
  missing one is how a domain move takes a business offline.

  Run it twice:

    1. Against Network Solutions, to confirm the inventory still matches what
       is live:

         .\dns-check.ps1 -Server ns23.worldnic.com

    2. Against Cloudflare, BEFORE switching the nameservers. Everything must
       pass first:

         .\dns-check.ps1 -Server <the nameserver Cloudflare assigned>

  CRITICAL rows are mail, plus the members CNAME the portal depends on. If any
  of those fail, do not switch the nameservers. INFO rows are worth
  understanding but will not take anything down.

  Exit code is 0 when every CRITICAL check passes, 1 otherwise.

  WHERE THIS INVENTORY CAME FROM, 21 September 2026
  -------------------------------------------------
  Three sources. The first two were each badly incomplete, and only the third
  is authoritative:

    1. Probing ns23.worldnic.com by hand found `members`, `staging` and the
       `*` wildcard, all three of which Cloudflare's import scan missed.
       But probing can only test names you already thought of.

    2. Cloudflare's import scan found `email`, `links`, `_acme-challenge`,
       `_cf-custom-hostname` and the two Microsoft 365 SRV records. It found
       22 records in total.

    3. The Network Solutions Advanced DNS panel - the actual zone - holds
       42 records. Reading it turned up 15 more that neither of the first two
       methods could see, including the PROOFPOINT DKIM SIGNING KEY, three
       Amazon SES DKIM CNAMEs, and `clubnow`, a second live Northstar host.

  Every record below was then confirmed to resolve against ns23.worldnic.com.
  Two rows in the panel, `em8743pinelakecc.com.` and `url8871pinelakecc.com.`,
  are malformed and resolve to nothing in any interpretation, so they are
  deliberately excluded - which is why this checks 40 and not 42. `portal`
  has no record at all; the REFUSED answer to an A query for it was a Network
  Solutions quirk, not a hidden record.

  The lesson is HANDOFF.md trap 6, and it is stronger than it was written:
  neither an absent DNS answer nor a provider's own import scan is evidence
  of what a zone contains. Only the zone is.
#>

param(
  [Parameter(Mandatory = $true)]
  [string]$Server,

  [string]$Zone = 'pinelakecc.com'
)

$ErrorActionPreference = 'Continue'
$criticalFailures = 0
$infoFailures = 0

function Normalize([string[]]$values) {
  if ($null -eq $values) { return @() }
  return @($values | ForEach-Object { $_.ToString().Trim().TrimEnd('.').ToLower() } | Sort-Object)
}

function Get-Answers([string]$name, [string]$type) {
  try {
    $r = Resolve-DnsName -Name $name -Type $type -Server $Server -DnsOnly -NoHostsFile -ErrorAction Stop
  } catch {
    return @()
  }
  switch ($type) {
    'MX'    { return @($r | Where-Object { $_.Type -eq 'MX' }    | ForEach-Object { "$($_.Preference) $($_.NameExchange)" }) }
    'TXT'   { return @($r | Where-Object { $_.Type -eq 'TXT' }   | ForEach-Object { ($_.Strings -join '') }) }
    'CNAME' { return @($r | Where-Object { $_.Type -eq 'CNAME' } | ForEach-Object { $_.NameHost }) }
    'A'     { return @($r | Where-Object { $_.Type -eq 'A' }     | ForEach-Object { $_.IPAddress }) }
    'SRV'   { return @($r | Where-Object { $_.Type -eq 'SRV' }   | ForEach-Object { "$($_.Priority) $($_.Weight) $($_.Port) $($_.NameTarget)" }) }
    default { return @() }
  }
}

function Check([string]$label, [string]$name, [string]$type, [string[]]$expected, [string]$severity) {
  $want = Normalize $expected
  $got  = Normalize (Get-Answers $name $type)

  if (($want -join "`n") -eq ($got -join "`n")) {
    Write-Host ("  PASS  " + $label)
    return
  }

  if ($severity -eq 'CRITICAL') {
    $script:criticalFailures++
    Write-Host ("  FAIL  " + $label + "   [CRITICAL - do not switch nameservers]") -ForegroundColor Red
  } else {
    $script:infoFailures++
    Write-Host ("  FAIL  " + $label + "   [info]") -ForegroundColor Yellow
  }
  Write-Host ("          expected: " + $(if ($want.Count) { $want -join ' | ' } else { '(nothing)' }))
  Write-Host ("          got:      " + $(if ($got.Count)  { $got  -join ' | ' } else { '(nothing)' }))
}

Write-Host ""
Write-Host ("Checking " + $Zone + " against " + $Server)
Write-Host ""

Write-Host "Mail - these are the ones that matter"

Check 'MX (Proofpoint, both hosts)' $Zone 'MX' @(
  '10 mx1-us1.ppe-hosted.com'
  '20 mx2-us1.ppe-hosted.com'
) 'CRITICAL'

Check 'TXT apex (SPF, M365 proof, Proofpoint proof, ca3)' $Zone 'TXT' @(
  'v=spf1 a mx ip4:96.66.39.42 a:dispatch-us.ppe-hosted.com include:spf.protection.outlook.com include:sendgrid.net include:amazonses.com ~all'
  'MS=ms21760240'
  'ca3-76bea5dfdfb44e5fb535bcb237ce2fbb'
  'ppe-dddb496a6869a2f3ac82b3b2d69d13928d3e9e21'
) 'CRITICAL'

Check 'TXT _dmarc (Proofpoint reporting)' ("_dmarc." + $Zone) 'TXT' @(
  'v=DMARC1; p=none; rua=mailto:dmarc_rua@emaildefense.proofpoint.com; ruf=mailto:dmarc_ruf@emaildefense.proofpoint.com; fo=1'
) 'CRITICAL'

Check 'CNAME s1._domainkey (SendGrid DKIM)' ("s1._domainkey." + $Zone) 'CNAME' @(
  's1.domainkey.u4668611.wl112.sendgrid.net'
) 'CRITICAL'

Check 'CNAME s2._domainkey (SendGrid DKIM)' ("s2._domainkey." + $Zone) 'CNAME' @(
  's2.domainkey.u4668611.wl112.sendgrid.net'
) 'CRITICAL'

Check 'CNAME email (SendGrid link branding)' ("email." + $Zone) 'CNAME' @(
  'u4668611.wl112.sendgrid.net'
) 'CRITICAL'

Check 'CNAME links (SendGrid click tracking)' ("links." + $Zone) 'CNAME' @(
  'sendgrid.net'
) 'CRITICAL'

Write-Host ""
Write-Host "Member portal - members must keep working through the move"

# Changed 21 Sept evening at Northstar's request (ticket #996907): the CNAME
# to pinelakecc-com.northstar-connect.com was replaced by an A record to their
# Cloudflare edge, plus two verification records, so Cloudflare will honour
# their custom hostname now that the zone is on Cloudflare in our account.
Check 'A members (Northstar edge, per their instruction)' ("members." + $Zone) 'A' @(
  '104.24.9.63'
) 'CRITICAL'
Check 'TXT _cf-custom-hostname.members (ownership token from Northstar)' ("_cf-custom-hostname.members." + $Zone) 'TXT' @(
  '8b03768f-10a5-4e60-990b-50fd22c1effc'
) 'CRITICAL'
Check 'CNAME _acme-challenge.members (delegated DCV)' ("_acme-challenge.members." + $Zone) 'CNAME' @(
  'members.pinelakecc.com.911c093aa0273216.dcv.cloudflare.com'
) 'CRITICAL'

Write-Host ""
Write-Host "Microsoft 365 service records"

Check 'CNAME autodiscover' ("autodiscover." + $Zone) 'CNAME' @('autodiscover.outlook.com') 'CRITICAL'
Check 'CNAME sip' ("sip." + $Zone) 'CNAME' @('sipdir.online.lync.com') 'INFO'
Check 'CNAME lyncdiscover' ("lyncdiscover." + $Zone) 'CNAME' @('webdir.online.lync.com') 'INFO'
Check 'CNAME enterpriseregistration' ("enterpriseregistration." + $Zone) 'CNAME' @('enterpriseregistration.windows.net') 'INFO'
Check 'CNAME enterpriseenrollment' ("enterpriseenrollment." + $Zone) 'CNAME' @('enterpriseenrollment.manage.microsoft.com') 'INFO'
Check 'SRV _sip._tls' ("_sip._tls." + $Zone) 'SRV' @('100 1 443 sipdir.online.lync.com') 'INFO'
Check 'SRV _sipfederationtls._tcp' ("_sipfederationtls._tcp." + $Zone) 'SRV' @('100 1 5061 sipfed.online.lync.com') 'INFO'

Write-Host ""
Write-Host "Northstar's certificate plumbing for the old site"

Check 'CNAME _acme-challenge' ("_acme-challenge." + $Zone) 'CNAME' @(
  'pinelakecc.com.911c093aa0273216.dcv.cloudflare.com'
) 'INFO'

Check 'TXT _cf-custom-hostname' ("_cf-custom-hostname." + $Zone) 'TXT' @(
  'cee63117-fc80-457c-acde-bbb9fef59b3d'
) 'INFO'

Write-Host ""
Write-Host "Records read out of the Network Solutions control panel, 21 Sept"
Write-Host "  (Cloudflare's import scan missed every one of these)"

Check 'TXT ppe._domainkey (PROOFPOINT DKIM SIGNING KEY)' ("ppe._domainkey." + $Zone) 'TXT' @(
  'v=DKIM1; k=rsa; t=s; n=core; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAn1rENKTy6i2tzYqsVIQpHsrjSBeO5KaD1lMN/ltm2NfLXvjD3Q6Oy97qrqlA6+ESh6FDkTdAumuCJbbGTWqW3Vpz6RkYzY0tFNP0NhZF80lxNy62ed9BrtEtVFv9KDUTwFFc1Ehwxzf8oQymsljkk2kQ1L8YnaQgTiFQ1UthVtEwrOF5/74tdTGT/8N5dcuiwSmnpq00A3Uq1ii6M0BdEBKaI+/IskS0p1Ni8QmQaZ8lkn4DKSXLo70eGPamAWhW3U6KA3HSKnOr/VjP9oSxBIaYCaW+1clI8HKVMQ7ZmgWLkm9VSkjEE/aug6xvMNa0+FF2BzM2IOKWv0Uc3WK9KwIDAQAB'
) 'CRITICAL'

Check 'CNAME SES DKIM 1 of 3' ("fgdjtutbucnhdpbjobgmx34rtb6jztwy._domainkey." + $Zone) 'CNAME' @('fgdjtutbucnhdpbjobgmx34rtb6jztwy.dkim.amazonses.com') 'CRITICAL'
Check 'CNAME SES DKIM 2 of 3' ("lqdjysclbun6mfr7nhd4y5duon3afovp._domainkey." + $Zone) 'CNAME' @('lqdjysclbun6mfr7nhd4y5duon3afovp.dkim.amazonses.com') 'CRITICAL'
Check 'CNAME SES DKIM 3 of 3' ("xpz24sk4bzcdhme6vtg7zk4xnhxtw7xl._domainkey." + $Zone) 'CNAME' @('xpz24sk4bzcdhme6vtg7zk4xnhxtw7xl.dkim.amazonses.com') 'CRITICAL'

Check 'CNAME s2._domainkey.emails (SendGrid DKIM, emails subdomain)' ("s2._domainkey.emails." + $Zone) 'CNAME' @('s2.domainkey.u4668611.wl112.sendgrid.net') 'CRITICAL'
Check 'CNAME clubnow (second Northstar host)' ("clubnow." + $Zone) 'CNAME' @('pinelakecc-com.northstar-connect.com') 'CRITICAL'
Check 'CNAME 4668611 (SendGrid)' ("4668611." + $Zone) 'CNAME' @('sendgrid.net') 'CRITICAL'
Check 'CNAME em7487.emails (SendGrid)' ("em7487.emails." + $Zone) 'CNAME' @('u4668611.wl112.sendgrid.net') 'CRITICAL'
Check 'CNAME url305.emails (SendGrid click tracking)' ("url305.emails." + $Zone) 'CNAME' @('sendgrid.net') 'CRITICAL'

Check 'A northstar' ("northstar." + $Zone) 'A' @('96.66.39.41') 'INFO'
Check 'A testing' ("testing." + $Zone) 'A' @('64.135.11.57') 'INFO'

Check 'CNAME Sectigo DCV 1 of 4' ("_0f6e4445e3229a65a7ed9dacf75612d8." + $Zone) 'CNAME' @('b95c60a448a32889ed38475bb7bcd36e.75e8955e1e830750384be46381573e7b.5har5g5fq35545qnq5f5.sectigo.com') 'INFO'
Check 'CNAME Sectigo DCV 2 of 4' ("_7122de11939d89f968408a9df0e5cfdf.northstar." + $Zone) 'CNAME' @('a2053e87a4499c60d8ccf4e51d84e9ce.fc60d1e32f15d7ed58507c2d0aaecec1.g5fc55dv5m5vtmjs52d5.sectigo.com') 'INFO'
Check 'CNAME Sectigo DCV 3 of 4' ("_93df93e28ac4099e438255ee8d7e6051.northstar." + $Zone) 'CNAME' @('2220b16448e1f651a284d768c295f196.45fb76926f2d8f4b988bb508bc9118e5.55ycg55o5kwg55d5555j.sectigo.com') 'INFO'
Check 'CNAME Sectigo DCV 4 of 4' ("_e9c258168ba8dc5006aa6de5a2cba7fa.northstar." + $Zone) 'CNAME' @('24500ae904eab7b11b152e8e66e6b8c9.e8dc5bdf5cd5c74742cecbefbf6e677a.55dqn955zt55l115shv4.sectigo.com') 'INFO'

Write-Host "Other records present at Network Solutions"

Check 'A staging (unidentified)' ("staging." + $Zone) 'A' @('64.135.45.138') 'INFO'
Check 'A * wildcard' ("zzz-wildcard-probe." + $Zone) 'A' @('64.135.11.57') 'INFO'

# portal.pinelakecc.com is NOT checked here. The name exists as a node in the
# zone - the wildcard does not answer for it, and other record types return
# NODATA rather than 64.135.11.57 - but Network Solutions answers an A query
# for it with REFUSED, so what it actually holds cannot be read over DNS.
# Read it out of the Network Solutions control panel by eye before the move.

Write-Host ""
Write-Host "----------------------------------------------------------------"
if ($criticalFailures -eq 0) {
  Write-Host "All CRITICAL checks passed." -ForegroundColor Green
  if ($infoFailures -gt 0) {
    Write-Host ("$infoFailures info-level difference(s) - understand them, but they will not break email.") -ForegroundColor Yellow
  }
  Write-Host ""
  Write-Host "Reminder: the apex A and www CNAME are deliberately NOT checked."
  Write-Host "Cloudflare creates those itself when you attach the Worker Custom"
  Write-Host "Domain. If the import scan recreated them, delete them first."
  Write-Host ""
  exit 0
} else {
  Write-Host ("$criticalFailures CRITICAL check(s) failed. DO NOT switch the nameservers.") -ForegroundColor Red
  Write-Host "Fix the records above and run this again."
  Write-Host ""
  exit 1
}

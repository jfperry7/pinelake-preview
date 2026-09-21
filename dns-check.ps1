<#
  dns-check.ps1 - compare one nameserver's answers against the record
  inventory for pinelakecc.com.

  The nameserver move is the one step of the cutover that can do real damage,
  and the damage is to the club's email, not the website. This checks the
  records by machine instead of by eye, because there are twenty-five of them
  and missing one is how a domain move takes a business offline.

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
  Two sources, because neither was complete on its own:

    - Probing ns23.worldnic.com by hand found `members`, `staging` and the
      `*` wildcard. Cloudflare's import scan MISSED all three. `members` is
      the member portal - had that gone unnoticed, the cutover would have
      locked every member out.

    - Cloudflare's import scan found `email`, `links`, `_acme-challenge`,
      `_cf-custom-hostname` and both Microsoft 365 SRV records. Hand-probing
      missed them because it only tested guessed names.

  Each one below was then confirmed against ns23.worldnic.com directly. The
  lesson is in HANDOFF.md trap 6: an absent DNS answer is not evidence that a
  record does not exist.
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

Check 'CNAME members (Northstar)' ("members." + $Zone) 'CNAME' @(
  'pinelakecc-com.northstar-connect.com'
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

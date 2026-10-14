<#
.SYNOPSIS
  Runs pgTAP test files against the linked (dev) Supabase project without Docker.
.DESCRIPTION
  `supabase test db` needs Docker for pg_prove. This runner sends each file through
  `supabase db query --linked` (Management API), which only returns the last result set, so
  every top-level assertion (`select <assertion>(...)` at column 0) is rewritten to insert its
  TAP line into a temp table that is read back at the end. Each file still runs inside its own
  begin/rollback, so nothing persists. Never point this at production.
.EXAMPLE
  ./scripts/pgtap-remote.ps1
  ./scripts/pgtap-remote.ps1 supabase/tests/01_rls_tenancy.test.sql
#>
param([string[]]$Paths = @(Get-ChildItem supabase/tests -Filter *.test.sql | Sort-Object Name | ForEach-Object FullName))

$notAssertions = '^(select\s+(plan|set_config|\*\s+from\s+finish)\b)'
$failed = 0

foreach ($path in $Paths) {
    $lines = (Get-Content $path) | ForEach-Object {
        if ($_ -match '^select\s+plan\(') {
            $_
            'create temp table _tap (n serial primary key, line text); grant all on _tap, _tap_n_seq to public;'
        } elseif ($_ -match '^select\s+\*\s+from\s+finish\(\);') {
            'reset role;'
            "select string_agg(line, E'\n' order by n) as tap, (select value from __tcache__ where label = 'plan') as planned, count(*) as ran from _tap;"
        } elseif ($_ -match '^select\s' -and $_ -notmatch $notAssertions) {
            'insert into _tap (line) ' + $_
        } else {
            $_
        }
    }

    $tmp = Join-Path $env:TEMP ("pgtap-" + [guid]::NewGuid() + ".sql")
    Set-Content -Path $tmp -Value ($lines -join "`n")
    $raw = (npx supabase db query --linked -f $tmp 2>&1 | ForEach-Object { "$_" }) -join "`n"
    Remove-Item $tmp

    Write-Host (Split-Path $path -Leaf) -ForegroundColor Cyan
    $start = $raw.IndexOf('{')
    $result = if ($start -ge 0) { $raw.Substring($start) | ConvertFrom-Json } else { $null }
    if (-not $result -or $result.error -or -not $result.rows) {
        Write-Host "  ERROR $raw" -ForegroundColor Red
        $failed++
        continue
    }

    $row = $result.rows[0]
    foreach ($line in ($row.tap -split "`n")) {
        $color = if ($line -match '^not ok') { $failed++; 'Red' } else { 'Gray' }
        Write-Host "  $line" -ForegroundColor $color
    }
    if ([int]$row.ran -ne [int]$row.planned) {
        Write-Host "  planned $($row.planned) tests but ran $($row.ran)" -ForegroundColor Red
        $failed++
    }
}

if ($failed) { Write-Host "$failed failure(s)" -ForegroundColor Red; exit 1 }
Write-Host 'All pgTAP tests passed' -ForegroundColor Green

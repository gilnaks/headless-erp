param([string[]]$Names, [switch]$Brief)
$root = "C:\Users\John\Desktop\erpnext\erpnext"
foreach ($n in $Names) {
  $slug = ($n.ToLower() -replace '[^a-z0-9]+','_').Trim('_')
  $f = Get-ChildItem -Path $root -Recurse -Filter "$slug.json" -ErrorAction SilentlyContinue | Where-Object { $_.Directory.Name -eq $slug -and $_.Directory.Parent.Name -eq 'doctype' } | Select-Object -First 1
  if (-not $f) { Write-Output "##### $n : NOT FOUND (maybe frappe core)"; continue }
  $j = Get-Content $f.FullName -Raw | ConvertFrom-Json
  $flags = @()
  if ($j.istable -eq 1) { $flags += 'child-table' }
  if ($j.is_submittable -eq 1) { $flags += 'submittable' }
  if ($j.issingle -eq 1) { $flags += 'single' }
  if ($j.is_tree -eq 1) { $flags += 'tree' }
  Write-Output "##### $n [$($j.module)] naming=$($j.naming_rule)/$($j.autoname) title=$($j.title_field) $($flags -join ',')"
  $skip = @('Section Break','Column Break','Tab Break','HTML','Button','Fold','Heading')
  foreach ($fd in $j.fields) {
    if ($skip -contains $fd.fieldtype) { continue }
    if ($Brief -and ($fd.hidden -eq 1 -or $fd.read_only -eq 1) -and $fd.fieldtype -notin @('Table','Link','Currency','Float')) { continue }
    $m = @()
    if ($fd.reqd -eq 1) { $m += 'reqd' }
    if ($fd.read_only -eq 1) { $m += 'ro' }
    if ($fd.hidden -eq 1) { $m += 'hidden' }
    if ($fd.default) { $m += "def=$($fd.default)" }
    if ($fd.fetch_from) { $m += "fetch=$($fd.fetch_from)" }
    if ($fd.unique -eq 1) { $m += 'unique' }
    $opt = ''
    if ($fd.options) { $opt = ($fd.options -replace "`n", '|') ; if ($opt.Length -gt 110) { $opt = $opt.Substring(0,110) + '…' } }
    Write-Output ("  {0} : {1}{2}{3}" -f $fd.fieldname, $fd.fieldtype, $(if($opt){" [$opt]"}else{''}), $(if($m){" {" + ($m -join ',') + "}"}else{''}))
  }
  if ($j.permissions) {
    $roles = ($j.permissions | Where-Object { $_.permlevel -eq 0 -or -not $_.permlevel } | ForEach-Object { "$($_.role)($(if($_.read){'r'})$(if($_.write){'w'})$(if($_.create){'c'})$(if($_.submit){'s'})$(if($_.cancel){'x'})$(if($_.delete){'d'}))" }) -join ', '
    Write-Output "  PERMS: $roles"
  }
  if ($j.states) { Write-Output "  STATES: $(($j.states | ForEach-Object { "$($_.title):$($_.color)" }) -join ', ')" }
}

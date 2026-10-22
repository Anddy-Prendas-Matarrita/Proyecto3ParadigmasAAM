param([string]$f)
Get-Content $f -Encoding UTF8 | ForEach-Object {
  if ($_ -match '^\s*--\s*\|\s?(.*)$') { "/// " + $Matches[1] }
  elseif ($_ -match '^\s*--\s?\^\s?(.*)$') { "///< " + $Matches[1] }
  elseif ($_ -match '^module\s+(\w+)') { "/// @file " + $Matches[1] + ".hs`nnamespace " + $Matches[1] + " {" }
  elseif ($_ -match '^(\w+)\s*::\s*(.*)$') { "/// @fn " + $Matches[1] + "`n/// Tipo: " + $Matches[2] + "`nvoid " + $Matches[1] + "();" }
  else { "" }
}
"}"

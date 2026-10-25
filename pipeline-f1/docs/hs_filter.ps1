param([string]$f)

# Salida UTF-8 sin BOM para que Doxygen lea bien las tildes.
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false

$out      = New-Object System.Collections.Generic.List[string]
$inData   = $false   # dentro de un bloque data/newtype
$inDoc    = $false   # la linea anterior fue comentario de documentacion
$params   = @()      # nombres de @param del comentario actual
$typeName = ''

foreach ($line in (Get-Content $f -Encoding UTF8)) {

  # Un bloque data termina con una linea en blanco o una linea en columna 0.
  if ($inData -and ($line -match '^\s*$' -or $line -match '^\S')) {
    $out.Add('};')
    $inData = $false
  }

  # "-- | texto" : inicio de comentario de documentacion
  if ($line -match '^\s*--\s*\|\s?(.*)$') {
    $text = $Matches[1]
    $out.Add('/// ' + $text)
    if ($text -match '@param\s+(\w+)') { $params += $Matches[1] }
    $inDoc = $true
    continue
  }

  # "-- ^ texto" : documentacion del elemento anterior
  if ($line -match '^\s*--\s?\^\s?(.*)$') {
    $out.Add('///< ' + $Matches[1])
    continue
  }

  # "--   texto" justo despues de un "-- |" : continuacion (@param, @return...)
  if ($inDoc -and $line -match '^\s*--\s?(.*)$') {
    $text = $Matches[1]
    $out.Add('/// ' + $text)
    if ($text -match '@param\s+(\w+)') { $params += $Matches[1] }
    continue
  }

  # Comentario normal: se ignora
  if ($line -match '^\s*--') { continue }

  $inDoc = $false

  # module X where
  if ($line -match '^module\s+(\w+)') {
    $out.Add('/// @file ' + $Matches[1] + '.hs')
    $out.Add('namespace ' + $Matches[1] + ' {')
    $params = @()
    continue
  }

  # data / newtype -> struct
  if ($line -cmatch '^(?:data|newtype)\s+([A-Z]\w*)(.*)$') {
    $typeName = $Matches[1]
    $rest     = $Matches[2]
    $out.Add('struct ' + $typeName + ' {')
    $inData = $true
    $params = @()
    if ($rest -match '=(.*)$') {
      $rhs = $Matches[1] -replace 'deriving.*$', ''
      foreach ($alt in ($rhs -split '\|')) {
        if ($alt -cmatch '^\s*([A-Z]\w*)' -and $Matches[1] -cne $typeName) {
          $out.Add('  void ' + $Matches[1] + '();')
        }
      }
    }
    continue
  }

  if ($inData) {
    # "= Ctor args" o "| Ctor args"  (con comentario opcional al final)
    if ($line -cmatch '^\s*[=|]\s*([A-Z]\w*)\s*(.*)$') {
      $ctor = $Matches[1]
      $tail = $Matches[2]
      $cm   = ''
      if ($tail -match '^(.*?)\s*--\s*[\^|]?\s*(.*)$') { $tail = $Matches[1]; $cm = $Matches[2] }
      $d = if ($tail.Trim()) { 'Argumentos: ' + $tail.Trim() } else { 'Sin argumentos' }
      if ($cm) { $d += ' (' + $cm + ')' }
      $out.Add('  void ' + $ctor + '(); ///< ' + $d)
      continue
    }
    # "{ campo :: Tipo" o ", campo :: Tipo"
    if ($line -match '^\s*[{,]\s*(\w+)\s*::\s*(.+)$') {
      $name = $Matches[1]
      $t    = $Matches[2]
      $c    = ''
      if ($t -match '^(.*?)\s*--\s*[\^|]?\s*(.*)$') { $t = $Matches[1]; $c = ' - ' + $Matches[2] }
      $out.Add('  int ' + $name + '; ///< Tipo: ' + $t.Trim() + $c)
      continue
    }
    continue
  }

  # firma de funcion: "nombre :: Tipo" (tambien "a, b :: Tipo")
  if ($line -cmatch '^([a-z_][\w'']*(?:\s*,\s*[a-z_][\w'']*)*)\s*::\s*(.*)$') {
    $names = $Matches[1] -split '\s*,\s*'
    $sig   = $Matches[2].Trim()
    $plist = ($params | ForEach-Object { 'int ' + $_ }) -join ', '
    $first = $true
    foreach ($n in $names) {
      if (-not $first) { $out.Add('') }
      $out.Add('/// @fn ' + $n)
      $out.Add('/// Tipo: ' + $sig)
      $out.Add('void ' + $n + '(' + $plist + ');')
      $first = $false
    }
    $params = @()
    continue
  }
}

if ($inData) { $out.Add('};') }
$out.Add('}')
$out -join "`n"

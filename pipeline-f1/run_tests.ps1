# Pruebas automaticas: Haskell + Prolog + archivos generados. Evidencia en evidencia\pruebas.txt
$ErrorActionPreference = "Continue"
chcp 65001 | Out-Null
# Decodificar la salida de cabal/swipl como UTF-8 (evita ver caracteres raros en la evidencia)
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false
$OutputEncoding = New-Object System.Text.UTF8Encoding $false
New-Item -ItemType Directory evidencia -Force | Out-Null
Start-Transcript -Path evidencia\pruebas.txt -Force | Out-Null

$fallos = 0
function Check($nombre, $cond) {
  if ($cond) { Write-Host "[OK]    $nombre" -ForegroundColor Green }
  else { Write-Host "[FALLO] $nombre" -ForegroundColor Red; $script:fallos++ }
}
function Salida { (Get-Content output\reporte_validacion.txt -Raw -Encoding UTF8) }

Write-Host "=== Compilacion Haskell ==="
cabal build 2>&1 | Out-Host
Check "cabal build" ($LASTEXITCODE -eq 0)

Write-Host "`n=== Caso 1: entrada valida (tests\ok.txt) ==="
cabal run pipeline -- tests\ok.txt 2>&1 | Out-Host
foreach ($f in "conocimiento.pl","consultas.pl","index.html","reporte_validacion.txt") {
  Check "genera $f" (Test-Path "output\$f")
}
Check "reporte: Estado OK" ((Salida) -match "Estado\s+: OK")
$pl = swipl -g ejecutar_todas -t halt output\consultas.pl 2>&1 | Out-String
Write-Host $pl
Check "Prolog sin warnings" ($pl -notmatch "Warning")
Check "Prolog: companeros(ana,luis)" ($pl -match "companeros\(ana,luis\)")
Check "Prolog: pendiente(luis,paradigmas)" ($pl -match "pendiente\(luis,paradigmas\)")
Check "Prolog: carga_docente(maria,2)" ($pl -match "carga_docente\(maria,2\)")
$html = Get-Content output\index.html -Raw -Encoding UTF8
Check "HTML contiene hechos y consultas" (($html -match "persona\(ana\)") -and ($html -match "companeros\(ana, X\)"))

Write-Host "`n=== Caso 2: entrada con errores (tests\errores.txt) ==="
cabal run pipeline -- tests\errores.txt 2>&1 | Out-Host
$r = Salida
Check "detecta entidad duplicada" ($r -match "duplicada")
Check "detecta formato invalido" ($r -match "formato")
Check "detecta entidad no declarada (Pedro)" ($r -match "Pedro")
Check "detecta regla fuera del dominio" ($r -match "rutas_posibles")
Check "detecta relacion con argumentos faltantes" ($r -match "imparte")
Check "estado CON ERRORES" ($r -match "CON ERRORES")
$e = swipl -g halt output\conocimiento.pl 2>&1 | Out-String
Check "conocimiento.pl con errores sigue cargando en Prolog" ($e -notmatch "Warning|ERROR")
Check "HTML muestra los errores" ((Get-Content output\index.html -Raw -Encoding UTF8) -match "no est. declarada")

Write-Host "`n=== Caso 3: seccion obligatoria ausente (tests\sin_reglas.txt) ==="
cabal run pipeline -- tests\sin_reglas.txt 2>&1 | Out-Host
Check "detecta seccion REGLAS_SOLICITADAS ausente" ((Salida) -match "REGLAS_SOLICITADAS")

Write-Host "`n=== Caso 4: segundo archivo (tests\otro.txt) ==="
cabal run pipeline -- tests\otro.txt 2>&1 | Out-Host
$pl2 = swipl -g ejecutar_todas -t halt output\consultas.pl 2>&1 | Out-String
Write-Host $pl2
Check "Prolog sin warnings" ($pl2 -notmatch "Warning")
Check "Prolog: companeros(carlos,elena)" ($pl2 -match "companeros\(carlos,elena\)")
Check "Prolog: carga_docente(jose,2)" ($pl2 -match "carga_docente\(jose,2\)")
Check "HTML regenerado con Carlos" ((Get-Content output\index.html -Raw -Encoding UTF8) -match "Carlos")

Write-Host "`n=== Caso 5: duplicados por mayusculas y tildes (tests\duplicados.txt) ==="
cabal run pipeline -- tests\duplicados.txt 2>&1 | Out-Host
$r5 = Salida
Check "detecta entidad duplicada (Sofia igual a Sofia con tilde)" ($r5 -match "entidad duplicada")
Check "detecta relacion duplicada" ($r5 -match "relaci.n duplicada")
$kb = Get-Content output\conocimiento.pl -Raw -Encoding UTF8
Check "hecho lleva(sofia, paradigmas) aparece una sola vez" (([regex]::Matches($kb, "lleva\(sofia, paradigmas\)")).Count -eq 1)

Write-Host "`n=== Restaurando salida del problema original (problema.txt) ==="
cabal run pipeline 2>&1 | Out-Null

Write-Host "`n=== Resumen: $fallos fallo(s) ==="
Stop-Transcript | Out-Null

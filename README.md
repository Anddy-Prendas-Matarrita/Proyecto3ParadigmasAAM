# Pipeline Funcional-Lógico: Haskell → Prolog → UI

Proyecto Integrador de Paradigmas de Programación.
Lee `problema.txt`, lo procesa con Haskell, genera una base de conocimiento Prolog y una interfaz web.

**Dominio:** académico (personas, cursos, docentes).

## Requisitos

| Herramienta | Versión | Uso |
|---|---|---|
| GHCup | última | Instala GHC y cabal |
| GHC | **9.4.8** | Compilador de Haskell |
| cabal | 3.x | Compilación del proyecto |
| SWI-Prolog | 9.x | Probar `conocimiento.pl` |
| Navegador web | cualquiera | Ver `index.html` |
| VS Code + extensión Haskell | opcional | Editor |

Espacio libre recomendado en `C:`: **mínimo 10 GB** (GHC falla al instalar si no hay espacio).

## Instalación (Windows)

### 1. GHCup

En PowerShell (sin administrador):

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force;[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; try { & ([ScriptBlock]::Create((Invoke-WebRequest https://www.haskell.org/ghcup/sh/bootstrap-haskell.ps1 -UseBasicParsing))) -Interactive -DisableCurl } catch { Write-Error $_ }
```

Respuestas sugeridas: ruta por defecto (Enter), HLS **N**, stack **N**, MSYS2 **Y**.
No cierres la terminal hasta que termine.

### 2. GHC 9.4.8 y cabal

Un comando por línea:

```powershell
$env:Path += ";C:\ghcup\bin"
ghcup install ghc 9.4.8
ghcup install cabal recommended
```

Verifica que existe el toolchain de GHC (debe dar `True`):

```powershell
Test-Path C:\ghcup\ghc\9.4.8\mingw
```

### 3. PATH

Si `ghc` o `cabal` no se reconocen, agrega las rutas a la sesión actual
(ajusta la versión de cabal según `ghcup whereis cabal <version>`):

```powershell
$env:Path = "C:\ghcup\ghc\9.4.8\bin;C:\ghcup\bin;" + $env:Path
```

Si cabal quedó en `C:\ghcup\cabal\<version>`, agrégala también:

```powershell
$env:Path += ";C:\ghcup\cabal\3.18.2.0"
```

Para hacerlo permanente, agrégalas a la variable de entorno `Path` de usuario y reinicia VS Code.

### 4. SWI-Prolog

Descarga el instalador desde <https://www.swi-prolog.org/Download.html> y marca
**"Add swipl to the system PATH"**. Verifica:

```powershell
swipl --version
```

## Ejecución

Desde la raíz del proyecto (donde está `pipeline-fl.cabal`):

```powershell
cabal update
cabal run pipeline
```

Si cabal no usa el GHC correcto:

```powershell
cabal run pipeline -w C:\ghcup\ghc\9.4.8\bin\ghc.exe
```

Para ver bien las tildes en la consola: `chcp 65001`.

## Archivos generados (carpeta `output/`)

| Archivo | Descripción |
|---|---|
| `reporte_validacion.txt` | Errores y advertencias del procesamiento |
| `conocimiento.pl` | Base de conocimiento Prolog (hechos, relaciones, reglas) |
| `consultas.pl` | Consultas sugeridas |
| `index.html` | Interfaz generada automáticamente |

Si cambias `problema.txt` y vuelves a ejecutar `cabal run pipeline`, todo se regenera.

## Probar en Prolog

```powershell
swipl output\conocimiento.pl
```

```prolog
?- companeros(ana, X).
?- pendiente(luis, C).
?- carga_docente(maria, N).
?- halt.
```

## Probar la interfaz

Abre `output/index.html` en el navegador.

## Formato de `problema.txt`

```
[ENTIDADES]
persona: Ana
curso: Paradigmas
docente: María

[RELACIONES]
lleva: Ana, Paradigmas
imparte: María, Paradigmas
aprueba: Ana, Paradigmas

[REGLAS_SOLICITADAS]
companeros
curso_con_docente
docente_de
pendiente
carga_docente
```

- Tipos de entidad: `persona`, `curso`, `docente`.
- Relaciones: `lleva` (persona, curso), `imparte` (docente, curso), `aprueba` (persona, curso).
- Reglas válidas: `companeros`, `curso_con_docente`, `docente_de`, `pendiente`, `carga_docente`.
- Líneas que empiezan con `#` son comentarios. Guardar el archivo en **UTF-8**.

## Estructura

```
├── pipeline-fl.cabal
├── problema.txt
├── README.md
├── app/Main.hs          Orquestación del pipeline
├── src/
│   ├── Types.hs         Modelo intermedio
│   ├── Parser.hs        Secciones y parsing
│   ├── Validator.hs     Validaciones y reporte
│   ├── PrologGen.hs     Generación de conocimiento.pl
│   └── FileIO.hs        Lectura/escritura UTF-8
└── output/              Archivos generados
```

## Problemas frecuentes

| Síntoma | Solución |
|---|---|
| `cabal`/`ghc` no se reconoce | Agregar rutas al PATH (paso 3) y reiniciar VS Code |
| `could not detect mingw toolchain` | Instalación de GHC incompleta: `ghcup rm ghc 9.4.8` y reinstalar con espacio libre |
| `not enough space on the disk` | Liberar espacio en `C:` (mínimo 10 GB) |
| `Permission denied` al enlazar `pipeline.exe` | Cerrar el proceso (`Get-Process pipeline \| Stop-Process`) y repetir; si persiste, excluir la carpeta del antivirus |
| `no .cabal package file` | Ejecutar desde la carpeta que contiene `pipeline-fl.cabal` |
| Pegar dos comandos juntos falla | Ejecutar un comando por línea |
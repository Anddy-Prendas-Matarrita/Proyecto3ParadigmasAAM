# Pipeline Funcional-Lógico: Haskell → Prolog → UI

Proyecto Integrador de Paradigmas de Programación.
Lee `problema.txt`, lo procesa con Haskell, genera una base de conocimiento Prolog, consultas sugeridas, un reporte de validación y una interfaz web (`index.html`).

**Dominio:** académico (personas, cursos, docentes).

## Pipeline

```
problema.txt
   │  FileIO.readUTF8
   ▼
Parser.parseProblem        → Problem (modelo intermedio con tipos propios)
   │
Validator.validate         → Problem limpio + errores/advertencias
   │
   ├─► Validator.renderReport       → output/reporte_validacion.txt
   ├─► PrologGen.generateKnowledge  → output/conocimiento.pl
   ├─► QueryGen.generateQueries     → output/consultas.pl
   └─► HtmlGen.generateHtml         → output/index.html
```

La interfaz se construye desde el mismo modelo intermedio que produce el `.pl`; nada está escrito a mano.

## Requisitos

| Herramienta | Versión | Uso |
|---|---|---|
| GHCup | última | Instala GHC y cabal |
| GHC | 9.4.8 (recomendado) o 9.10.3 | Compilador de Haskell |
| cabal | 3.x | Compilación del proyecto |
| SWI-Prolog | 9.x o 10.x | Probar `conocimiento.pl` y `consultas.pl` |
| Navegador web | cualquiera | Ver `index.html` |
| Doxygen | 1.9+ | Documentación (opcional) |
| VS Code + extensión Haskell | opcional | Editor |

Espacio libre recomendado en `C:`: **mínimo 10 GB** (GHC falla al instalar si no hay espacio).

## Instalación (Windows)

Ejecutar **un comando por línea** en PowerShell.

### 1. GHCup

En PowerShell (sin administrador):

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force;[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; try { & ([ScriptBlock]::Create((Invoke-WebRequest https://www.haskell.org/ghcup/sh/bootstrap-haskell.ps1 -UseBasicParsing))) -Interactive -DisableCurl } catch { Write-Error $_ }
```

Respuestas sugeridas: ruta por defecto (Enter), HLS **N**, stack **N**, MSYS2 **Y**.
No cierres la terminal hasta que termine.

### 2. GHC y cabal

```powershell
$env:Path += ";C:\ghcup\bin"
ghcup install ghc 9.4.8
ghcup install cabal recommended
```

Verifica el toolchain de GHC (debe dar `True`):

```powershell
Test-Path C:\ghcup\ghc\9.4.8\mingw
```

### 3. PATH

Si `ghc` o `cabal` no se reconocen, agrégalos a la sesión actual:

```powershell
$env:Path = "C:\ghcup\ghc\9.4.8\bin;C:\ghcup\bin;" + $env:Path
```

Si cabal quedó en `C:\ghcup\cabal\<version>` (consulta con `ghcup whereis cabal <version>`):

```powershell
$env:Path += ";C:\ghcup\cabal\3.18.2.0"
```

Para hacerlo permanente, agrega las rutas a la variable de entorno `Path` de usuario y reinicia VS Code.

### 4. SWI-Prolog

```powershell
winget install SWI-Prolog.SWI-Prolog
```

O descarga el instalador desde <https://www.swi-prolog.org/Download.html> y marca **"Add swipl to the system PATH"**. Si no se reconoce:

```powershell
$env:Path += ";C:\Program Files\swipl\bin"
swipl --version
```

### 5. Doxygen (opcional)

```powershell
winget install DimitriVanHeesch.Doxygen
doxygen --version
```

## Ejecución

Desde la carpeta que contiene `pipeline-fl.cabal`:

```powershell
cabal update
cabal run pipeline
```

Para usar otro archivo de entrada (por ejemplo, el del docente):

```powershell
cabal run pipeline -- ruta\otro_problema.txt
```

Sin argumento usa `problema.txt`. Cada ejecución regenera todo en `output/`.

Si cabal no usa el GHC correcto:

```powershell
cabal run pipeline -w C:\ghcup\ghc\9.4.8\bin\ghc.exe
```

Para ver bien las tildes en la consola: `chcp 65001` (los archivos generados siempre quedan en UTF-8).

## Archivos generados (carpeta `output/`)

| Archivo | Descripción |
|---|---|
| `reporte_validacion.txt` | Errores y advertencias del procesamiento |
| `conocimiento.pl` | Base de conocimiento Prolog: hechos con comentarios de trazabilidad (`% linea N`) y reglas |
| `consultas.pl` | Consultas sugeridas y el predicado `ejecutar_todas` |
| `index.html` | Interfaz generada automáticamente |

## Probar en Prolog

Conocimiento:

```powershell
swipl output\conocimiento.pl
```

```prolog
?- companeros(ana, X).
?- pendiente(luis, C).
?- carga_docente(maria, N).
?- halt.
```

Todas las consultas sugeridas:

```powershell
swipl -g ejecutar_todas -t halt output\consultas.pl
```

## Probar la interfaz

```powershell
start output\index.html
```

Muestra entidades, relaciones, hechos Prolog, reglas, consultas sugeridas (con botón Copiar), errores/advertencias y el contenido de `conocimiento.pl`.

## Formato de `problema.txt`

```
[ENTIDADES]
persona: Ana
persona: Luis
curso: Paradigmas
docente: María

[RELACIONES]
lleva: Ana, Paradigmas
lleva: Luis, Paradigmas
imparte: María, Paradigmas
aprueba: Ana, Paradigmas

[REGLAS_SOLICITADAS]
companeros
curso_con_docente
docente_de
pendiente
carga_docente
```

- Secciones obligatorias: `[ENTIDADES]`, `[RELACIONES]`, `[REGLAS_SOLICITADAS]`.
- Tipos de entidad: `persona`, `curso`, `docente`.
- Relaciones: `lleva` (persona, curso), `imparte` (docente, curso), `aprueba` (persona, curso).
- Reglas válidas: `companeros`, `curso_con_docente`, `docente_de`, `pendiente`, `carga_docente`.
- Líneas vacías o que empiezan con `#` se ignoran. Guardar el archivo en **UTF-8**.

## Reglas Prolog generadas

| Regla | Significado |
|---|---|
| `companeros(X, Y)` | X e Y llevan al menos un curso en común |
| `curso_con_docente(Curso, Docente)` | Docente que imparte el curso |
| `docente_de(Persona, Docente)` | Docente que imparte un curso que lleva la persona |
| `pendiente(Persona, Curso)` | La persona lleva el curso y no lo ha aprobado |
| `carga_docente(Docente, N)` | Cantidad de cursos que imparte el docente |

## Validaciones

- Entidades duplicadas (advertencia, se ignoran).
- Relaciones con entidades no declaradas o de tipo incorrecto (error).
- Líneas con formato inválido (error).
- Secciones obligatorias ausentes (error) y secciones desconocidas (advertencia).
- Reglas que no corresponden al dominio (advertencia, se ignoran).
- Líneas fuera de toda sección (advertencia).

El resultado queda en `output/reporte_validacion.txt` y en la sección *Errores y advertencias* de la interfaz.

## Pruebas

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
.\run_tests.ps1
```

Ejecuta 4 casos (entrada válida, entrada con errores, sección ausente y segundo archivo distinto), y valida Haskell, SWI-Prolog y los archivos generados, incluida la regeneración del HTML.
Archivos de prueba en `tests/`. Evidencia en `evidencia/pruebas.txt`; capturas del navegador y de Prolog en `evidencia/`.

Al terminar, restaura la salida del problema original:

```powershell
cabal run pipeline
```

## Documentación (Doxygen)

```powershell
doxygen Doxyfile
start docs\doxygen\html\index.html
```

La explicación del pipeline está en `docs/pipeline.md` (página principal de Doxygen).
El filtro `docs/hs_filter.ps1` convierte los comentarios `-- |` de Haskell para Doxygen.

## Estructura

```
├── pipeline-fl.cabal
├── problema.txt
├── README.md
├── Doxyfile
├── run_tests.ps1
├── app/
│   └── Main.hs          Orquestación del pipeline
├── src/
│   ├── Types.hs         Modelo intermedio
│   ├── FileIO.hs        Lectura/escritura UTF-8
│   ├── Parser.hs        Secciones y parsing
│   ├── Validator.hs     Validaciones y reporte
│   ├── PrologGen.hs     Generación de conocimiento.pl
│   ├── QueryGen.hs      Generación de consultas.pl
│   └── HtmlGen.hs       Generación de index.html
├── tests/               Entradas de prueba (ok, errores, sin_reglas, otro)
├── evidencia/           Resultado de pruebas y capturas
├── docs/                pipeline.md, hs_filter.ps1 y salida de Doxygen
└── output/              Archivos generados
```

## Problemas frecuentes

| Síntoma | Solución |
|---|---|
| `cabal`/`ghc`/`swipl` no se reconoce | Agregar rutas al PATH (pasos 3 y 4) y reiniciar VS Code |
| `could not detect mingw toolchain` | Instalación de GHC incompleta: `ghcup rm ghc 9.4.8` y reinstalar con espacio libre |
| `not enough space on the disk` | Liberar espacio en `C:` (mínimo 10 GB) |
| `Permission denied` al enlazar `pipeline.exe` | Cerrar el proceso (`Get-Process pipeline \| Stop-Process`) y repetir; si persiste, excluir la carpeta del antivirus |
| `no .cabal package file` | Ejecutar desde la carpeta que contiene `pipeline-fl.cabal` |
| `missing-home-modules` (warning) | Agregar el módulo a `other-modules` en `pipeline-fl.cabal` |
| `Doxygen: input source does not exist` | Ejecutar `doxygen Doxyfile` desde la raíz del proyecto |
| `run_tests.ps1` no se reconoce | Estar en la raíz del proyecto y ejecutar `Set-ExecutionPolicy Bypass -Scope Process -Force` |
| Caracteres raros en consola (`├ô`) | `chcp 65001`; el archivo generado está bien |
| Pegar dos comandos juntos falla | Ejecutar un comando por línea |
# Pipeline Haskell -> Prolog -> UI

Dominio academico: personas, cursos y docentes.

## Flujo

```
problema.txt
   |  FileIO.readUTF8
   v
Parser.parseProblem     -> Problem (modelo intermedio, tipos propios)
   |
Validator.validate      -> Problem limpio + errores/advertencias
   |
   +--> Validator.renderReport  -> reporte_validacion.txt
   +--> PrologGen.generateKnowledge -> conocimiento.pl
   +--> QueryGen.generateQueries    -> consultas.pl
   +--> HtmlGen.generateHtml        -> index.html
```

## Modulos

| Modulo | Responsabilidad |
|---|---|
| Types | Entity, Relation, Annotated, Message, Problem |
| Parser | Secciones `[NOMBRE]` y parsing de lineas con Either |
| Validator | Duplicados, entidades no declaradas, reglas fuera del dominio, secciones ausentes |
| PrologGen | Hechos con trazabilidad (`% linea N`) y reglas |
| QueryGen | Consultas sugeridas y `ejecutar_todas` |
| HtmlGen | UI generada desde el mismo modelo |
| Main | Orquestacion; acepta ruta de entrada por argumento |

## Uso

`cabal run pipeline` o `cabal run pipeline -- ruta\otro.txt`.
Cambiar `problema.txt` regenera todo en `output/` sin editar la pagina.
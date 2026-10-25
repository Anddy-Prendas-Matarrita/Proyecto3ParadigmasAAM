# Pipeline Haskell -> Prolog -> UI

Proyecto Integrador de Paradigmas de Programacion. El sistema transforma una
descripcion textual estructurada (`problema.txt`) en una base de conocimiento
Prolog, consultas sugeridas, un reporte de validacion y una interfaz web.

Dominio academico: personas, cursos y docentes.

## Flujo general

```
problema.txt
   |  FileIO.readUTF8
   v
Parser.parseProblem     -> Problem (modelo intermedio, tipos propios)
   |
Validator.validate      -> Problem limpio + errores/advertencias
   |
   +--> Validator.renderReport      -> output/reporte_validacion.txt
   +--> PrologGen.generateKnowledge -> output/conocimiento.pl
   +--> QueryGen.generateQueries    -> output/consultas.pl
   +--> HtmlGen.generateHtml        -> output/index.html
```

1. **Lectura**: `FileIO.readUTF8` lee el archivo en UTF-8.
2. **Parsing**: `Parser.parseProblem` separa las secciones `[NOMBRE]` y convierte
   cada linea en un valor del modelo usando `Either`, de modo que las lineas
   invalidas se convierten en mensajes de error y no detienen el proceso.
3. **Validacion**: `Validator.validate` elimina duplicados, descarta relaciones
   con entidades no declaradas y reglas fuera del dominio, y revisa las secciones.
4. **Generacion**: los cuatro generadores reciben el mismo `Problem` validado.
   La interfaz se construye desde ese modelo; nada esta escrito a mano.

## Modulos

| Modulo | Responsabilidad |
|---|---|
| Types | Modelo intermedio: Entity, Relation, Annotated, Message, Problem |
| FileIO | Lectura y escritura de archivos en UTF-8 |
| Parser | Secciones `[NOMBRE]` y parsing de lineas con Either |
| Validator | Validaciones semanticas y reporte de texto |
| PrologGen | Hechos con trazabilidad (`% linea N`) y reglas del dominio |
| QueryGen | Consultas sugeridas y el predicado `ejecutar_todas` |
| HtmlGen | Interfaz web generada desde el mismo modelo |
| Main | Orquestacion; acepta la ruta de entrada por argumento |

## Modelo intermedio

El modelo esta definido en el modulo Types. Cada elemento se guarda dentro de
`Annotated`, que conserva la linea y el texto de origen para la trazabilidad.

```haskell
data Entity   = Person String | Course String | Teacher String
data Relation = Takes String String      -- lleva
              | Teaches String String    -- imparte
              | Passes String String     -- aprueba

data Problem = Problem
  { entities       :: [Annotated Entity]
  , relations      :: [Annotated Relation]
  , requestedRules :: [Annotated String]
  , foundSections  :: [String]
  , warnings       :: [Message]
  , errors         :: [Message]
  }
```

## Formato de entrada

```
[ENTIDADES]
persona: Ana
curso: Paradigmas
docente: Maria

[RELACIONES]
lleva: Ana, Paradigmas
imparte: Maria, Paradigmas

[REGLAS_SOLICITADAS]
companeros
docente_de
```

## Validaciones

| Validacion | Gravedad |
|---|---|
| Entidades duplicadas (mismo tipo y mismo atomo Prolog) | Advertencia, se ignora |
| Relaciones duplicadas | Advertencia, se ignora |
| Relaciones con entidades no declaradas o de tipo incorrecto | Error |
| Lineas con formato invalido o tipos y relaciones desconocidos | Error |
| Secciones obligatorias ausentes | Error |
| Reglas que no corresponden al dominio | Advertencia, se ignora |
| Lineas fuera de toda seccion y secciones desconocidas | Advertencia |

El resultado se escribe en `reporte_validacion.txt` y se muestra en la
interfaz, con los mensajes ordenados por numero de linea.

## Ejemplo de transformacion

Linea de entrada:

```
lleva: Sofia, Bases de Datos
```

Hecho generado en `conocimiento.pl`, con su comentario de trazabilidad:

```prolog
% linea 12: lleva: Sofia, Bases de Datos
lleva(sofia, bases_de_datos).
```

Consulta sugerida en `consultas.pl`:

```prolog
consulta(8, 'Companeros de sofia', 'companeros(sofia, X)').
```

## Reglas Prolog del dominio

| Regla | Significado |
|---|---|
| companeros(X, Y) | X e Y llevan al menos un curso en comun |
| curso_con_docente(Curso, Docente) | Docente que imparte el curso |
| docente_de(Persona, Docente) | Docente que imparte un curso que lleva la persona |
| pendiente(Persona, Curso) | La persona lleva el curso y no lo ha aprobado |
| carga_docente(Docente, N) | Cantidad de cursos que imparte el docente |

## Interfaz de usuario

`HtmlGen.generateHtml` produce `index.html` con entidades, relaciones, hechos
Prolog, reglas, consultas sugeridas (con boton para copiar), errores y
advertencias, y el contenido completo de `conocimiento.pl`.

## Uso

```
cabal run pipeline
cabal run pipeline -- ruta/otro.txt
```

Cambiar `problema.txt` regenera todo en `output/` sin editar la pagina.
Las pruebas automaticas se ejecutan con `run_tests.ps1`.

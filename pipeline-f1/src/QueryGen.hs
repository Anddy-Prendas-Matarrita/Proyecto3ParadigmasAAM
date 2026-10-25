-- | @brief Generacion de consultas Prolog sugeridas (consultas.pl).
--
--   Las consultas base son fijas y las consultas por regla se instancian con
--   las entidades reales del problema. La interfaz web reutiliza la misma lista.
module QueryGen (Query(..), suggestedQueries, generateQueries) where

import PrologGen (atomOf, quoteAtom)
import Types

-- | @brief Consulta sugerida: descripcion para humanos y objetivo Prolog.
data Query = Query
  { queryDesc :: String   -- ^ Descripcion legible de la consulta.
  , queryGoal :: String   -- ^ Objetivo Prolog, sin el prefijo de consulta ni el punto final.
  } deriving (Show, Eq)

-- | @brief Nombres de las entidades de cada tipo.
--   @param p Problema validado.
--   @return Lista de nombres tal como se declararon.
persons, courses, teachers :: Problem -> [String]
persons  p = [ n | a <- entities p, Person n  <- [value a] ]
courses  p = [ n | a <- entities p, Course n  <- [value a] ]
teachers p = [ n | a <- entities p, Teacher n <- [value a] ]

-- | @brief Consultas generales que siempre se sugieren.
baseQueries :: [Query]
baseQueries =
  [ Query "Todas las personas"        "persona(X)"
  , Query "Todos los cursos"          "curso(X)"
  , Query "Todos los docentes"        "docente(X)"
  , Query "Que curso lleva cada persona" "lleva(P, C)"
  , Query "Que curso imparte cada docente" "imparte(D, C)"
  ]

-- | @brief Consultas de una regla solicitada, instanciadas con las entidades del modelo.
--   @param p Problema validado.
--   @param rule Nombre de la regla.
--   @return Una consulta por cada entidad relevante, o ninguna si la regla no se conoce.
ruleQueries :: Problem -> String -> [Query]
ruleQueries p "companeros" =
  [ Query ("Companeros de " ++ atomOf n) ("companeros(" ++ quoteAtom n ++ ", X)")
  | n <- persons p ]
ruleQueries p "curso_con_docente" =
  [ Query ("Docente del curso " ++ atomOf n) ("curso_con_docente(" ++ quoteAtom n ++ ", D)")
  | n <- courses p ]
ruleQueries p "docente_de" =
  [ Query ("Docentes de " ++ atomOf n) ("docente_de(" ++ quoteAtom n ++ ", D)")
  | n <- persons p ]
ruleQueries p "pendiente" =
  [ Query ("Cursos pendientes de " ++ atomOf n) ("pendiente(" ++ quoteAtom n ++ ", C)")
  | n <- persons p ]
ruleQueries p "carga_docente" =
  [ Query ("Carga de " ++ atomOf n) ("carga_docente(" ++ quoteAtom n ++ ", N)")
  | n <- teachers p ]
ruleQueries _ _ = []

-- | @brief Lista completa de consultas sugeridas (tambien usada por la interfaz).
--   @param p Problema validado.
--   @return Consultas base seguidas de las consultas de cada regla solicitada.
suggestedQueries :: Problem -> [Query]
suggestedQueries p =
  baseQueries ++ concatMap (ruleQueries p . value) (requestedRules p)

-- | @brief Codigo Prolog del predicado ejecutar_todas.
--   Ejecuta cada consulta y muestra sus resultados sin repetidos.
runner :: [String]
runner =
  [ "% Ejecuta todas las consultas y muestra sus resultados (sin repetidos)."
  , "ejecutar_todas :-"
  , "    forall(consulta(N, Desc, Texto),"
  , "           ( format('~w. ~w~n', [N, Desc]),"
  , "             term_to_atom(Goal, Texto),"
  , "             findall(Goal, Goal, Rs0),"
  , "             list_to_set(Rs0, Rs),"
  , "             (   Rs == []"
  , "             ->  format('   (sin resultados)~n')"
  , "             ;   forall(member(R, Rs), format('   ~q~n', [R]))"
  , "             ) ))."
  ]

-- | @brief Genera el texto completo de consultas.pl.
--   @param p Problema validado.
--   @return Contenido del archivo: carga del conocimiento, consultas y predicado ejecutar_todas.
generateQueries :: Problem -> String
generateQueries p = unlines $
  [ "% ============================================"
  , "% consultas.pl - consultas sugeridas (generado automaticamente)"
  , "% Uso: swipl consultas.pl   y luego   ?- ejecutar_todas."
  , "% ============================================"
  , ""
  , ":- ensure_loaded('conocimiento.pl')."
  , ""
  , "% consulta(Numero, Descripcion, ObjetivoComoTexto)"
  ]
  ++ zipWith fmt [1 :: Int ..] (suggestedQueries p)
  ++ [""] ++ runner
  where
    fmt n q = "consulta(" ++ show n ++ ", '" ++ escQ (queryDesc q) ++ "', '"
              ++ escQ (queryGoal q) ++ "')."
    escQ = concatMap (\c -> if c == '\'' then "\\'" else [c])

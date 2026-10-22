-- | Suggested Prolog queries derived from the validated model.
module QueryGen (Query(..), suggestedQueries, generateQueries) where

import PrologGen (atomOf, quoteAtom)
import Types

-- | A suggested query: human description and Prolog goal.
data Query = Query
  { queryDesc :: String
  , queryGoal :: String
  } deriving (Show, Eq)

persons, courses, teachers :: Problem -> [String]
persons  p = [ n | a <- entities p, Person n  <- [value a] ]
courses  p = [ n | a <- entities p, Course n  <- [value a] ]
teachers p = [ n | a <- entities p, Teacher n <- [value a] ]

baseQueries :: [Query]
baseQueries =
  [ Query "Todas las personas"        "persona(X)"
  , Query "Todos los cursos"          "curso(X)"
  , Query "Todos los docentes"        "docente(X)"
  , Query "Que curso lleva cada persona" "lleva(P, C)"
  , Query "Que curso imparte cada docente" "imparte(D, C)"
  ]

-- | Queries for one requested rule, instantiated with the model's entities.
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

-- | All suggested queries (also used by the UI generator).
suggestedQueries :: Problem -> [Query]
suggestedQueries p =
  baseQueries ++ concatMap (ruleQueries p . value) (requestedRules p)

runner :: [String]
runner =
  [ "% Ejecuta todas las consultas y muestra sus resultados."
  , "ejecutar_todas :-"
  , "    forall(consulta(N, Desc, Texto),"
  , "           ( format('~w. ~w~n', [N, Desc]),"
  , "             term_to_atom(Goal, Texto),"
  , "             findall(Goal, Goal, Rs),"
  , "             (   Rs == []"
  , "             ->  format('   (sin resultados)~n')"
  , "             ;   forall(member(R, Rs), format('   ~q~n', [R]))"
  , "             ) ))."
  ]

-- | Full text of consultas.pl.
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
    fmt n q = "consulta(" ++ show n ++ ", '" ++ queryDesc q ++ "', '"
              ++ queryGoal q ++ "')."
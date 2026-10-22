-- | Prolog knowledge-base generation from the validated model.
module PrologGen (generateKnowledge, atomOf, quoteAtom, entityFact, relationFact, ruleCode) where
import Data.Char (isAlphaNum, isAscii, isLower, toLower)
import Types

-- | Removes accents and maps to plain ASCII lowercase.
foldChar :: Char -> Char
foldChar c = case toLower c of
  'á' -> 'a'; 'é' -> 'e'; 'í' -> 'i'; 'ó' -> 'o'; 'ú' -> 'u'
  'ü' -> 'u'; 'ñ' -> 'n'
  x   -> x

-- | Converts a name to a valid Prolog atom body: "Bases de Datos" -> bases_de_datos.
atomOf :: String -> String
atomOf = collapse . map toUnderscore . map foldChar
  where
    toUnderscore c
      | isAscii c && isAlphaNum c = c
      | otherwise                 = '_'
    collapse (a : b : r) | a == '_' && b == '_' = collapse (b : r)
    collapse (a : r) = a : collapse r
    collapse [] = []

-- | Ensures the atom starts with a lowercase letter, quoting otherwise.
quoteAtom :: String -> String
quoteAtom s = case atomOf s of
  a@(c : _) | isLower c -> a
  a                     -> "'" ++ a ++ "'"

entityFact :: Entity -> String
entityFact (Person n)  = "persona(" ++ quoteAtom n ++ ")."
entityFact (Course n)  = "curso(" ++ quoteAtom n ++ ")."
entityFact (Teacher n) = "docente(" ++ quoteAtom n ++ ")."

relationFact :: Relation -> String
relationFact (Takes a b)   = "lleva(" ++ quoteAtom a ++ ", " ++ quoteAtom b ++ ")."
relationFact (Teaches a b) = "imparte(" ++ quoteAtom a ++ ", " ++ quoteAtom b ++ ")."
relationFact (Passes a b)  = "aprueba(" ++ quoteAtom a ++ ", " ++ quoteAtom b ++ ")."

traced :: Annotated a -> (a -> String) -> [String]
traced a f = ["% linea " ++ show (srcLine a) ++ ": " ++ srcText a, f (value a), ""]

-- | Prolog source for each supported rule.
ruleCode :: String -> [String]
ruleCode "companeros" =
  [ "% companeros(X, Y): X e Y llevan al menos un curso en comun."
  , "companeros(X, Y) :-"
  , "    lleva(X, Curso),"
  , "    lleva(Y, Curso),"
  , "    X \\= Y." ]
ruleCode "curso_con_docente" =
  [ "% curso_con_docente(Curso, Docente): docente que imparte el curso."
  , "curso_con_docente(Curso, Docente) :-"
  , "    curso(Curso),"
  , "    imparte(Docente, Curso)." ]
ruleCode "docente_de" =
  [ "% docente_de(Persona, Docente): el docente imparte un curso que lleva la persona."
  , "docente_de(Persona, Docente) :-"
  , "    lleva(Persona, Curso),"
  , "    imparte(Docente, Curso)." ]
ruleCode "pendiente" =
  [ "% pendiente(Persona, Curso): la persona lleva el curso y no lo ha aprobado."
  , "pendiente(Persona, Curso) :-"
  , "    lleva(Persona, Curso),"
  , "    \\+ aprueba(Persona, Curso)." ]
ruleCode "carga_docente" =
  [ "% carga_docente(Docente, N): cantidad de cursos que imparte el docente."
  , "carga_docente(Docente, N) :-"
  , "    docente(Docente),"
  , "    findall(C, imparte(Docente, C), Cs),"
  , "    length(Cs, N)." ]
ruleCode other = ["% regla sin implementacion: " ++ other]

declarations :: [String]
declarations =
  [ ":- discontiguous persona/1, curso/1, docente/1."
  , ":- dynamic persona/1, curso/1, docente/1."
  , ":- dynamic lleva/2, imparte/2, aprueba/2."
  , "" ]

-- | Full text of conocimiento.pl.
generateKnowledge :: Problem -> String
generateKnowledge p = unlines $
  [ "% ============================================"
  , "% conocimiento.pl - generado automaticamente"
  , "% ============================================"
  , "" ]
  ++ declarations
  ++ ["% --- Entidades ---", ""]
  ++ concat [ traced a entityFact   | a <- entities p ]
  ++ ["% --- Relaciones ---", ""]
  ++ concat [ traced a relationFact | a <- relations p ]
  ++ ["% --- Reglas ---", ""]
  ++ concat [ ruleCode (value r) ++ [""] | r <- requestedRules p ]
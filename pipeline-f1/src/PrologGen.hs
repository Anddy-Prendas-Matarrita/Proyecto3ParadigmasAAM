-- | @brief Generacion de la base de conocimiento Prolog (conocimiento.pl).
--
--   Convierte el modelo intermedio validado en hechos Prolog con comentarios
--   de trazabilidad (linea de origen) y en las reglas del dominio academico.
module PrologGen (generateKnowledge, atomOf, quoteAtom, entityFact, relationFact, ruleCode) where

import Data.Char (isAlphaNum, isAscii, isLower, toLower)
import Types

-- | @brief Quita tildes y pasa un caracter a minuscula ASCII.
--   @param c Caracter original.
--   @return Caracter sin acento en minuscula.
foldChar :: Char -> Char
foldChar c = case toLower c of
  'á' -> 'a'; 'é' -> 'e'; 'í' -> 'i'; 'ó' -> 'o'; 'ú' -> 'u'
  'ü' -> 'u'; 'ñ' -> 'n'
  x   -> x

-- | @brief Convierte un nombre en el cuerpo de un atomo Prolog valido.
--   Ejemplo: Bases de Datos se convierte en bases_de_datos.
--   @param s Nombre tal como aparece en problema.txt.
--   @return Texto en minuscula ASCII con guion bajo en lugar de separadores.
atomOf :: String -> String
atomOf = collapse . map toUnderscore . map foldChar
  where
    toUnderscore c
      | isAscii c && isAlphaNum c = c
      | otherwise                 = '_'
    collapse (a : b : r) | a == '_' && b == '_' = collapse (b : r)
    collapse (a : r) = a : collapse r
    collapse [] = []

-- | @brief Garantiza que el atomo empiece con minuscula, entre comillas si es necesario.
--   @param s Nombre original.
--   @return Atomo Prolog listo para escribirse en el archivo.
quoteAtom :: String -> String
quoteAtom s = case atomOf s of
  a@(c : _) | isLower c -> a
  a                     -> "'" ++ a ++ "'"

-- | @brief Genera el hecho Prolog de una entidad.
--   @param e Entidad del modelo.
--   @return Hecho terminado en punto, por ejemplo persona(ana).
entityFact :: Entity -> String
entityFact (Person n)  = "persona(" ++ quoteAtom n ++ ")."
entityFact (Course n)  = "curso(" ++ quoteAtom n ++ ")."
entityFact (Teacher n) = "docente(" ++ quoteAtom n ++ ")."

-- | @brief Genera el hecho Prolog de una relacion.
--   @param r Relacion del modelo.
--   @return Hecho terminado en punto, por ejemplo lleva(ana, paradigmas).
relationFact :: Relation -> String
relationFact (Takes a b)   = "lleva(" ++ quoteAtom a ++ ", " ++ quoteAtom b ++ ")."
relationFact (Teaches a b) = "imparte(" ++ quoteAtom a ++ ", " ++ quoteAtom b ++ ")."
relationFact (Passes a b)  = "aprueba(" ++ quoteAtom a ++ ", " ++ quoteAtom b ++ ")."

-- | @brief Antepone el comentario de trazabilidad a un hecho.
--   @param a Valor anotado con su linea de origen.
--   @param f Funcion que genera el hecho.
--   @return Comentario con la linea, el hecho y una linea en blanco.
traced :: Annotated a -> (a -> String) -> [String]
traced a f = ["% linea " ++ show (srcLine a) ++ ": " ++ srcText a, f (value a), ""]

-- | @brief Codigo Prolog de cada regla soportada por el dominio.
--   @param name Nombre de la regla solicitada.
--   @return Lineas de codigo Prolog con su comentario descriptivo.
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

-- | @brief Directivas Prolog que declaran los predicados dinamicos y discontiguos.
declarations :: [String]
declarations =
  [ ":- discontiguous persona/1, curso/1, docente/1."
  , ":- dynamic persona/1, curso/1, docente/1."
  , ":- dynamic lleva/2, imparte/2, aprueba/2."
  , "" ]

-- | @brief Genera el texto completo de conocimiento.pl.
--   @param p Problema ya validado.
--   @return Contenido del archivo: directivas, hechos con trazabilidad y reglas.
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

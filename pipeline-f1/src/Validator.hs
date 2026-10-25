-- | @brief Validacion semantica del modelo intermedio y generacion del reporte.
--
--   Detecta entidades duplicadas, relaciones con entidades no declaradas,
--   reglas fuera del dominio y secciones obligatorias ausentes. Los nombres
--   se comparan por su atomo Prolog, de modo que Sofia y sofia (o con tilde)
--   se consideran el mismo elemento.
module Validator (validate, renderReport, domainRules) where

import Data.Either (partitionEithers)
import Data.List (sortOn)
import Data.Maybe (catMaybes)
import PrologGen (atomOf)
import Types

-- | @brief Reglas soportadas por el dominio academico.
domainRules :: [String]
domainRules =
  ["companeros", "curso_con_docente", "docente_de", "pendiente", "carga_docente"]

-- | @brief Secciones que debe tener todo archivo de entrada.
requiredSections :: [String]
requiredSections = ["ENTIDADES", "RELACIONES", "REGLAS_SOLICITADAS"]

-- | @brief Obtiene el nombre de una entidad.
--   @param e Entidad.
--   @return Nombre tal como se escribio en el archivo.
entityName :: Entity -> String
entityName (Person n)  = n
entityName (Course n)  = n
entityName (Teacher n) = n

-- | @brief Obtiene el tipo de una entidad como texto.
--   @param e Entidad.
--   @return persona, curso o docente.
entityKind :: Entity -> String
entityKind (Person _)  = "persona"
entityKind (Course _)  = "curso"
entityKind (Teacher _) = "docente"

-- | @brief Indica si dos entidades son la misma (mismo tipo y mismo atomo Prolog).
--   @param a Primera entidad.
--   @param b Segunda entidad.
--   @return True si son equivalentes.
sameEntity :: Entity -> Entity -> Bool
sameEntity a b =
  entityKind a == entityKind b && atomOf (entityName a) == atomOf (entityName b)

-- | @brief Descompone una relacion en su nombre y sus dos argumentos tipados.
--   @param r Relacion.
--   @return Nombre de la relacion y pares tipo y nombre de cada argumento.
relationParts :: Relation -> (String, (String, String), (String, String))
relationParts (Takes a b)   = ("lleva",   ("persona", a), ("curso", b))
relationParts (Teaches a b) = ("imparte", ("docente", a), ("curso", b))
relationParts (Passes a b)  = ("aprueba", ("persona", a), ("curso", b))

-- | @brief Indica si dos relaciones son la misma, ignorando mayusculas y tildes.
--   @param a Primera relacion.
--   @param b Segunda relacion.
--   @return True si producirian el mismo hecho Prolog.
sameRelation :: Relation -> Relation -> Bool
sameRelation a b = key a == key b
  where key r = let (n, (_, x), (_, y)) = relationParts r in (n, atomOf x, atomOf y)

-- | @brief Elimina duplicados conservando la primera aparicion.
--   @param same Criterio de igualdad.
--   @param label Texto usado en la advertencia (entidad, relacion, regla).
--   @param xs Elementos anotados.
--   @return Elementos sin duplicados y las advertencias de los repetidos.
dedupeBy :: (a -> a -> Bool) -> String -> [Annotated a] -> ([Annotated a], [Message])
dedupeBy same label = foldl step ([], [])
  where
    step (kept, msgs) a = case filter (same (value a) . value) kept of
      (first : _) ->
        ( kept
        , msgs ++ [Message SevWarning (Just (srcLine a))
            (label ++ " duplicada '" ++ srcText a ++ "' (ya declarada en línea "
              ++ show (srcLine first) ++ "), se ignora")] )
      [] -> (kept ++ [a], msgs)

-- | @brief Verifica que el argumento de una relacion este declarado con el tipo correcto.
--   @param ents Entidades declaradas.
--   @param arg Par con el tipo esperado y el nombre usado.
--   @return Nothing si es correcto, o el texto del problema.
checkArg :: [Entity] -> (String, String) -> Maybe String
checkArg ents (k, n)
  | any (\e -> entityKind e == k && sameName e) ents = Nothing
  | any sameName ents =
      Just ("'" ++ n ++ "' existe pero no está declarada como " ++ k)
  | otherwise = Just ("'" ++ n ++ "' no está declarada (se esperaba " ++ k ++ ")")
  where sameName e = atomOf (entityName e) == atomOf n

-- | @brief Verifica que los dos argumentos de una relacion esten declarados.
--   @param ents Entidades declaradas.
--   @param a Relacion anotada.
--   @return La relacion si es valida, o la lista de errores.
checkRelation :: [Entity] -> Annotated Relation -> Either [Message] (Annotated Relation)
checkRelation ents a =
  case catMaybes [checkArg ents x, checkArg ents y] of
    [] -> Right a
    ms -> Left [ Message SevError (Just (srcLine a))
                   ("relación '" ++ srcText a ++ "': " ++ m) | m <- ms ]
  where (_, x, y) = relationParts (value a)

-- | @brief Verifica que una regla solicitada pertenezca al dominio.
--   @param a Regla anotada.
--   @return La regla si es valida, o una advertencia.
checkRule :: Annotated String -> Either Message (Annotated String)
checkRule a
  | value a `elem` domainRules = Right a
  | otherwise = Left (Message SevWarning (Just (srcLine a))
      ("regla '" ++ value a ++ "' no corresponde al dominio académico, se ignora"))

-- | @brief Validacion pura del modelo.
--   Elimina duplicados, descarta relaciones invalidas y reglas fuera del dominio,
--   y verifica las secciones. Los mensajes quedan ordenados por numero de linea.
--   @param p Problema producido por el parser.
--   @return Problema depurado con los errores y advertencias adicionales.
validate :: Problem -> Problem
validate p = p
  { entities       = ents
  , relations      = rels
  , requestedRules = rules
  , warnings       = sortOn messageLine
                       (warnings p ++ dupEntW ++ dupRelW ++ ruleW ++ unknownSecW)
  , errors         = sortOn messageLine (errors p ++ relE ++ missingSecE)
  }
  where
    (ents, dupEntW) = dedupeBy sameEntity "entidad" (entities p)
    (relErrs, validRels) =
      partitionEithers (map (checkRelation (map value ents)) (relations p))
    relE = concat relErrs
    (rels, dupRelW) = dedupeBy sameRelation "relación" validRels
    (ruleW, okRules) = partitionEithers (map checkRule (requestedRules p))
    rules = fst (dedupeBy (==) "regla" okRules)
    missingSecE =
      [ Message SevError Nothing ("falta la sección obligatoria [" ++ s ++ "]")
      | s <- requiredSections, s `notElem` foundSections p ]
    unknownSecW =
      [ Message SevWarning Nothing ("sección desconocida [" ++ s ++ "], se ignora")
      | s <- foundSections p, s `notElem` requiredSections ]

-- | @brief Da formato a un mensaje para el reporte de texto.
--   @param m Mensaje.
--   @return Linea de texto con la ubicacion y la descripcion.
fmtMessage :: Message -> String
fmtMessage m =
  "  " ++ maybe "[general]" (\n -> "[línea " ++ show n ++ "]") (messageLine m)
    ++ " " ++ description m

-- | @brief Arma un bloque del reporte con titulo y lista de mensajes.
--   @param title Titulo del bloque.
--   @param ms Mensajes a mostrar.
--   @return Lineas del bloque.
section :: String -> [Message] -> [String]
section title ms =
  [ ""
  , title ++ " (" ++ show (length ms) ++ ")"
  ] ++ (if null ms then ["  (ninguno)"] else map fmtMessage ms)

-- | @brief Genera el texto de reporte_validacion.txt.
--   @param p Problema ya validado.
--   @return Contenido completo del reporte.
renderReport :: Problem -> String
renderReport p = unlines $
  [ "REPORTE DE VALIDACIÓN"
  , "====================="
  , "Entidades válidas : " ++ show (length (entities p))
  , "Relaciones válidas: " ++ show (length (relations p))
  , "Reglas aceptadas  : " ++ show (length (requestedRules p))
  , "Estado            : " ++ (if null (errors p) then "OK" else "CON ERRORES")
  ] ++ section "ERRORES" (errors p) ++ section "ADVERTENCIAS" (warnings p)

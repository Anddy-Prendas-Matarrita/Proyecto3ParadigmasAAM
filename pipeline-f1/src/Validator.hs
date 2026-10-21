-- | Semantic validation of the intermediate model and report rendering.
module Validator (validate, renderReport, domainRules) where

import Data.Char (toLower)
import Data.Either (partitionEithers)
import Data.Maybe (catMaybes)
import Types

-- | Rules supported by the academic domain.
domainRules :: [String]
domainRules =
  ["companeros", "curso_con_docente", "docente_de", "pendiente", "carga_docente"]

requiredSections :: [String]
requiredSections = ["ENTIDADES", "RELACIONES", "REGLAS_SOLICITADAS"]

norm :: String -> String
norm = map toLower

entityName :: Entity -> String
entityName (Person n)  = n
entityName (Course n)  = n
entityName (Teacher n) = n

entityKind :: Entity -> String
entityKind (Person _)  = "persona"
entityKind (Course _)  = "curso"
entityKind (Teacher _) = "docente"

sameEntity :: Entity -> Entity -> Bool
sameEntity a b =
  entityKind a == entityKind b && norm (entityName a) == norm (entityName b)

-- | (relation name, (kind, name) of 1st arg, (kind, name) of 2nd arg)
relationParts :: Relation -> (String, (String, String), (String, String))
relationParts (Takes a b)   = ("lleva",   ("persona", a), ("curso", b))
relationParts (Teaches a b) = ("imparte", ("docente", a), ("curso", b))
relationParts (Passes a b)  = ("aprueba", ("persona", a), ("curso", b))

-- | Removes duplicates keeping the first occurrence; warns about the rest.
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

checkArg :: [Entity] -> (String, String) -> Maybe String
checkArg ents (k, n)
  | any (\e -> entityKind e == k && norm (entityName e) == norm n) ents = Nothing
  | any (\e -> norm (entityName e) == norm n) ents =
      Just ("'" ++ n ++ "' existe pero no está declarada como " ++ k)
  | otherwise = Just ("'" ++ n ++ "' no está declarada (se esperaba " ++ k ++ ")")

checkRelation :: [Entity] -> Annotated Relation -> Either [Message] (Annotated Relation)
checkRelation ents a =
  case catMaybes [checkArg ents x, checkArg ents y] of
    [] -> Right a
    ms -> Left [ Message SevError (Just (srcLine a))
                   ("relación '" ++ srcText a ++ "': " ++ m) | m <- ms ]
  where (_, x, y) = relationParts (value a)

checkRule :: Annotated String -> Either Message (Annotated String)
checkRule a
  | value a `elem` domainRules = Right a
  | otherwise = Left (Message SevWarning (Just (srcLine a))
      ("regla '" ++ value a ++ "' no corresponde al dominio académico, se ignora"))

-- | Pure validation: returns a cleaned model plus extra errors/warnings.
-- | Pure validation: returns a cleaned model plus extra errors/warnings.
validate :: Problem -> Problem
validate p = p
  { entities       = ents
  , relations      = rels
  , requestedRules = rules
  , warnings       = warnings p ++ dupEntW ++ dupRelW ++ ruleW ++ unknownSecW
  , errors         = errors p ++ relE ++ missingSecE
  }
  where
    (ents, dupEntW) = dedupeBy sameEntity "entidad" (entities p)
    (relErrs, validRels) =
      partitionEithers (map (checkRelation (map value ents)) (relations p))
    relE = concat relErrs
    (rels, dupRelW) = dedupeBy (==) "relación" validRels
    (ruleW, okRules) = partitionEithers (map checkRule (requestedRules p))
    rules = fst (dedupeBy (==) "regla" okRules)
    missingSecE =
      [ Message SevError Nothing ("falta la sección obligatoria [" ++ s ++ "]")
      | s <- requiredSections, s `notElem` foundSections p ]
    unknownSecW =
      [ Message SevWarning Nothing ("sección desconocida [" ++ s ++ "], se ignora")
      | s <- foundSections p, s `notElem` requiredSections ]
fmtMessage :: Message -> String
fmtMessage m =
  "  " ++ maybe "[general]" (\n -> "[línea " ++ show n ++ "]") (messageLine m)
    ++ " " ++ description m

section :: String -> [Message] -> [String]
section title ms =
  [ ""
  , title ++ " (" ++ show (length ms) ++ ")"
  ] ++ (if null ms then ["  (ninguno)"] else map fmtMessage ms)
-- | Text of reporte_validacion.txt.
renderReport :: Problem -> String
renderReport p = unlines $
  [ "REPORTE DE VALIDACIÓN"
  , "====================="
  , "Entidades válidas : " ++ show (length (entities p))
  , "Relaciones válidas: " ++ show (length (relations p))
  , "Reglas aceptadas  : " ++ show (length (requestedRules p))
  , "Estado            : " ++ (if null (errors p) then "OK" else "CON ERRORES")
  ] ++ section "ERRORES" (errors p) ++ section "ADVERTENCIAS" (warnings p)
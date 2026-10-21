-- | Section splitting and functional parsing into the intermediate model.
module Parser (parseProblem) where

import Data.Char (isAlphaNum, isSpace, toLower, toUpper)
import Data.Either (partitionEithers)
import Data.Maybe (fromMaybe, isJust)
import Types

trim :: String -> String
trim = f . f where f = reverse . dropWhile isSpace

stripBOM :: String -> String
stripBOM ('\xFEFF' : r) = r
stripBOM s = s

numberLines :: String -> [SourceLine]
numberLines = zipWith SourceLine [1 ..] . lines . stripBOM

-- | Meaningful line (not empty and not a '#' comment).
isUseful :: SourceLine -> Bool
isUseful l = case trim (lineText l) of
  []        -> False
  ('#' : _) -> False
  _         -> True

-- | Detects '[NAME]' and returns NAME in uppercase.
parseHeader :: String -> Maybe String
parseHeader s = case trim s of
  ('[' : rest) | not (null rest), last rest == ']'
               -> Just (map toUpper (trim (init rest)))
  _            -> Nothing

-- | Returns (lines before the first section, sections).
splitSections :: [SourceLine] -> ([SourceLine], [Section])
splitSections ls = (orphans, sections rest)
  where
    isHeader = isJust . parseHeader . lineText
    (orphans, rest) = break isHeader ls
    sections [] = []
    sections (h : t) = Section name (lineNumber h) body : sections next
      where
        name = fromMaybe "" (parseHeader (lineText h))
        (body, next) = break isHeader t

linesOf :: String -> [Section] -> [SourceLine]
linesOf n ss =
  filter isUseful (concat [sectionLines s | s <- ss, sectionName s == n])

-- | "key: value" -> (lowercase key, value)
splitKey :: String -> Maybe (String, String)
splitKey s = case break (== ':') s of
  (k, ':' : v) | not (null (trim k)), not (null (trim v))
               -> Just (map toLower (trim k), trim v)
  _            -> Nothing

splitCommas :: String -> [String]
splitCommas s = case break (== ',') s of
  (a, [])    -> [trim a]
  (a, _ : r) -> trim a : splitCommas r

errorAt :: SourceLine -> String -> Message
errorAt l = Message SevError (Just (lineNumber l))

annotate :: SourceLine -> a -> Annotated a
annotate l = Annotated (lineNumber l) (trim (lineText l))

parseEntity :: SourceLine -> Either Message (Annotated Entity)
parseEntity l = case splitKey (lineText l) of
  Just ("persona", n) -> Right (annotate l (Person n))
  Just ("curso", n)   -> Right (annotate l (Course n))
  Just ("docente", n) -> Right (annotate l (Teacher n))
  Just (k, _)         -> Left (errorAt l ("tipo de entidad desconocido: '" ++ k ++ "'"))
  Nothing             -> Left (errorAt l "formato inválido, se esperaba 'tipo: nombre'")

parseRelation :: SourceLine -> Either Message (Annotated Relation)
parseRelation l = case splitKey (lineText l) of
  Nothing -> Left (errorAt l "formato inválido, se esperaba 'relacion: a, b'")
  Just (k, v) -> case (k, splitCommas v) of
    ("lleva",   [a, b]) | valid [a, b] -> Right (annotate l (Takes a b))
    ("imparte", [a, b]) | valid [a, b] -> Right (annotate l (Teaches a b))
    ("aprueba", [a, b]) | valid [a, b] -> Right (annotate l (Passes a b))
    (r, _)
      | r `elem` ["lleva", "imparte", "aprueba"] ->
          Left (errorAt l ("la relación '" ++ r ++ "' requiere exactamente 2 argumentos no vacíos"))
      | otherwise ->
          Left (errorAt l ("relación desconocida: '" ++ r ++ "'"))
  where valid = all (not . null)

parseRule :: SourceLine -> Either Message (Annotated String)
parseRule l
  | not (null name) && all (\c -> isAlphaNum c || c == '_') name
      = Right (annotate l (map toLower name))
  | otherwise = Left (errorAt l "formato inválido, se esperaba un nombre de regla")
  where name = trim (lineText l)

-- | Main pure function: text -> intermediate model.
parseProblem :: String -> Problem
parseProblem txt = Problem
  { entities       = es
  , relations      = rs
  , requestedRules = gs
  , foundSections  = map sectionName sections
  , warnings       = orphanWarnings
  , errors         = entErrs ++ relErrs ++ ruleErrs
  }
  where
    (orphans, sections) = splitSections (numberLines txt)
    (entErrs, es)  = partitionEithers (map parseEntity   (linesOf "ENTIDADES" sections))
    (relErrs, rs)  = partitionEithers (map parseRelation (linesOf "RELACIONES" sections))
    (ruleErrs, gs) = partitionEithers (map parseRule     (linesOf "REGLAS_SOLICITADAS" sections))
    orphanWarnings =
      [ Message SevWarning (Just (lineNumber l)) "línea fuera de toda sección, se ignora"
      | l <- filter isUseful orphans ]
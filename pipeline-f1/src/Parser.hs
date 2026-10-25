-- | @brief Separacion en secciones y parsing funcional hacia el modelo intermedio.
--
--   Todas las funciones de este modulo son puras: reciben el texto de
--   problema.txt y devuelven un Problem sin realizar entrada o salida.
module Parser (parseProblem) where

import Data.Char (isAlphaNum, isSpace, toLower, toUpper)
import Data.Either (partitionEithers)
import Data.Maybe (fromMaybe, isJust)
import Types

-- | @brief Elimina los espacios al inicio y al final de un texto.
--   @param s Texto de entrada.
--   @return Texto sin espacios en los extremos.
trim :: String -> String
trim = f . f where f = reverse . dropWhile isSpace

-- | @brief Quita la marca BOM de UTF-8 si el archivo la trae.
--   @param s Contenido completo del archivo.
--   @return Contenido sin BOM.
stripBOM :: String -> String
stripBOM ('\xFEFF' : r) = r
stripBOM s = s

-- | @brief Numera las lineas del archivo empezando en 1.
--   @param s Contenido completo del archivo.
--   @return Lista de lineas con su numero.
numberLines :: String -> [SourceLine]
numberLines = zipWith SourceLine [1 ..] . lines . stripBOM

-- | @brief Indica si una linea es significativa.
--   Se descartan las lineas vacias y las que empiezan con almohadilla.
--   @param l Linea a evaluar.
--   @return True si la linea debe procesarse.
isUseful :: SourceLine -> Bool
isUseful l = case trim (lineText l) of
  []        -> False
  ('#' : _) -> False
  _         -> True

-- | @brief Detecta un encabezado de seccion entre corchetes.
--   @param s Texto de la linea.
--   @return El nombre en mayusculas, o Nothing si no es un encabezado.
parseHeader :: String -> Maybe String
parseHeader s = case trim s of
  ('[' : rest) | not (null rest), last rest == ']'
               -> Just (map toUpper (trim (init rest)))
  _            -> Nothing

-- | @brief Divide las lineas en secciones.
--   @param ls Lineas numeradas del archivo.
--   @return Par con las lineas anteriores a la primera seccion y la lista de secciones.
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

-- | @brief Obtiene las lineas significativas de una seccion por nombre.
--   @param n Nombre de la seccion en mayusculas.
--   @param ss Secciones encontradas.
--   @return Lineas utiles de todas las secciones con ese nombre.
linesOf :: String -> [Section] -> [SourceLine]
linesOf n ss =
  filter isUseful (concat [sectionLines s | s <- ss, sectionName s == n])

-- | @brief Separa una linea con formato clave y valor separados por dos puntos.
--   @param s Texto de la linea.
--   @return Par con la clave en minusculas y el valor, o Nothing si el formato es invalido.
splitKey :: String -> Maybe (String, String)
splitKey s = case break (== ':') s of
  (k, ':' : v) | not (null (trim k)), not (null (trim v))
               -> Just (map toLower (trim k), trim v)
  _            -> Nothing

-- | @brief Separa un texto por comas y recorta cada parte.
--   @param s Texto con valores separados por comas.
--   @return Lista de valores sin espacios sobrantes.
splitCommas :: String -> [String]
splitCommas s = case break (== ',') s of
  (a, [])    -> [trim a]
  (a, _ : r) -> trim a : splitCommas r

-- | @brief Construye un mensaje de error asociado a una linea.
--   @param l Linea de origen.
--   @param msg Texto del error.
--   @return Mensaje de gravedad error.
errorAt :: SourceLine -> String -> Message
errorAt l = Message SevError (Just (lineNumber l))

-- | @brief Agrega trazabilidad (linea y texto original) a un valor.
--   @param l Linea de origen.
--   @param x Valor del modelo.
--   @return Valor anotado.
annotate :: SourceLine -> a -> Annotated a
annotate l = Annotated (lineNumber l) (trim (lineText l))

-- | @brief Convierte una linea de la seccion ENTIDADES en una entidad.
--   @param l Linea con formato tipo y nombre.
--   @return Entidad anotada, o un mensaje de error.
parseEntity :: SourceLine -> Either Message (Annotated Entity)
parseEntity l = case splitKey (lineText l) of
  Just ("persona", n) -> Right (annotate l (Person n))
  Just ("curso", n)   -> Right (annotate l (Course n))
  Just ("docente", n) -> Right (annotate l (Teacher n))
  Just (k, _)         -> Left (errorAt l ("tipo de entidad desconocido: '" ++ k ++ "'"))
  Nothing             -> Left (errorAt l "formato inválido, se esperaba 'tipo: nombre'")

-- | @brief Convierte una linea de la seccion RELACIONES en una relacion.
--   @param l Linea con formato relacion, dos puntos y dos argumentos separados por coma.
--   @return Relacion anotada, o un mensaje de error.
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

-- | @brief Convierte una linea de la seccion REGLAS_SOLICITADAS en un nombre de regla.
--   @param l Linea con el nombre de la regla.
--   @return Nombre en minusculas anotado, o un mensaje de error.
parseRule :: SourceLine -> Either Message (Annotated String)
parseRule l
  | not (null name) && all (\c -> isAlphaNum c || c == '_') name
      = Right (annotate l (map toLower name))
  | otherwise = Left (errorAt l "formato inválido, se esperaba un nombre de regla")
  where name = trim (lineText l)

-- | @brief Funcion principal del parser: transforma el texto en el modelo intermedio.
--   Separa las secciones, parsea cada una con Either y acumula los errores de formato.
--   @param txt Contenido completo de problema.txt.
--   @return Problema con entidades, relaciones, reglas, secciones y mensajes.
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

-- | @brief Modelo intermedio del pipeline Haskell, Prolog y UI.
--
--   Contiene los tipos de datos propios con los que se representa el problema
--   leido desde problema.txt. El Parser los construye, el Validator los depura
--   y los generadores (PrologGen, QueryGen y HtmlGen) los consumen.
module Types where

-- | @brief Linea cruda del archivo de entrada junto con su numero.
data SourceLine = SourceLine
  { lineNumber :: Int      -- ^ Numero de linea, empezando en 1.
  , lineText   :: String   -- ^ Texto original de la linea.
  } deriving (Show, Eq)

-- | @brief Seccion del archivo de entrada, por ejemplo la seccion ENTIDADES.
data Section = Section
  { sectionName  :: String       -- ^ Nombre de la seccion en mayusculas.
  , headerLine   :: Int          -- ^ Numero de linea donde aparece el encabezado.
  , sectionLines :: [SourceLine] -- ^ Lineas que pertenecen a la seccion.
  } deriving (Show, Eq)

-- | @brief Entidad declarada en la seccion ENTIDADES.
data Entity
  = Person String    -- persona, el campo es su nombre
  | Course String    -- curso, el campo es su nombre
  | Teacher String   -- docente, el campo es su nombre
  deriving (Show, Eq)

-- | @brief Relacion declarada en la seccion RELACIONES.
data Relation
  = Takes String String     -- lleva: persona y curso
  | Teaches String String   -- imparte: docente y curso
  | Passes String String    -- aprueba: persona y curso
  deriving (Show, Eq)

-- | @brief Valor con trazabilidad: guarda la linea y el texto de origen.
--
--   Permite generar los comentarios de trazabilidad en conocimiento.pl y
--   los mensajes de error con numero de linea.
data Annotated a = Annotated
  { srcLine :: Int      -- ^ Numero de linea de origen.
  , srcText :: String   -- ^ Texto original de esa linea, sin espacios sobrantes.
  , value   :: a        -- ^ Valor del modelo (entidad, relacion o regla).
  } deriving (Show, Eq)

-- | @brief Gravedad de un mensaje de validacion.
data Severity
  = SevError     -- error: el elemento no es utilizable
  | SevWarning   -- advertencia: se ignora el elemento y se continua
  deriving (Show, Eq)

-- | @brief Mensaje de error o advertencia producido por el Parser o el Validator.
data Message = Message
  { severity    :: Severity   -- ^ Error o advertencia.
  , messageLine :: Maybe Int  -- ^ Linea afectada, o Nothing si es un mensaje general.
  , description :: String     -- ^ Texto explicativo del problema.
  } deriving (Show, Eq)

-- | @brief Problema completo: es el modelo intermedio que usan todos los generadores.
data Problem = Problem
  { entities       :: [Annotated Entity]    -- ^ Entidades validas con su linea de origen.
  , relations      :: [Annotated Relation]  -- ^ Relaciones validas con su linea de origen.
  , requestedRules :: [Annotated String]    -- ^ Nombres de reglas solicitadas y aceptadas.
  , foundSections  :: [String]              -- ^ Nombres de las secciones encontradas.
  , warnings       :: [Message]             -- ^ Advertencias detectadas.
  , errors         :: [Message]             -- ^ Errores detectados.
  } deriving (Show, Eq)

-- | Intermediate model of the pipeline.
module Types where

-- | Raw source line with its number.
data SourceLine = SourceLine
  { lineNumber :: Int
  , lineText   :: String
  } deriving (Show, Eq)

-- | A '[NAME]' section with its lines.
data Section = Section
  { sectionName  :: String
  , headerLine   :: Int
  , sectionLines :: [SourceLine]
  } deriving (Show, Eq)

data Entity
  = Person String
  | Course String
  | Teacher String
  deriving (Show, Eq)

data Relation
  = Takes String String     -- person, course
  | Teaches String String   -- teacher, course
  | Passes String String    -- person, course
  deriving (Show, Eq)

-- | Value with traceability (source line number and original text).
data Annotated a = Annotated
  { srcLine :: Int
  , srcText :: String
  , value   :: a
  } deriving (Show, Eq)

data Severity = SevError | SevWarning deriving (Show, Eq)

data Message = Message
  { severity    :: Severity
  , messageLine :: Maybe Int
  , description :: String
  } deriving (Show, Eq)

data Problem = Problem
  { entities       :: [Annotated Entity]
  , relations      :: [Annotated Relation]
  , requestedRules :: [Annotated String]
  , foundSections  :: [String]
  , warnings       :: [Message]
  , errors         :: [Message]
  } deriving (Show, Eq)
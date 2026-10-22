module Main (main) where

import FileIO (readUTF8, writeUTF8)
import HtmlGen (generateHtml)
import Parser (parseProblem)
import PrologGen (generateKnowledge)
import QueryGen (generateQueries)
import System.Directory (createDirectoryIfMissing, doesFileExist)
import System.Environment (getArgs)
import System.Exit (exitFailure)
import System.IO (hPutStrLn, hSetEncoding, stderr, stdout, utf8)
import Types
import Validator (renderReport, validate)

outputDir :: FilePath
outputDir = "output"

-- | Input path: first CLI argument, or problema.txt by default.
inputFrom :: [String] -> FilePath
inputFrom (x : _) = x
inputFrom []      = "problema.txt"

main :: IO ()
main = do
  hSetEncoding stdout utf8
  input  <- inputFrom <$> getArgs
  exists <- doesFileExist input
  if not exists
    then hPutStrLn stderr ("Error: no se encontró " ++ input) >> exitFailure
    else do
      txt <- readUTF8 input
      let problem = validate (parseProblem txt)
      createDirectoryIfMissing True outputDir
      writeUTF8 (outputDir ++ "/reporte_validacion.txt") (renderReport problem)
      writeUTF8 (outputDir ++ "/conocimiento.pl")        (generateKnowledge problem)
      writeUTF8 (outputDir ++ "/consultas.pl")           (generateQueries problem)
      writeUTF8 (outputDir ++ "/index.html")             (generateHtml problem)
      putStr (renderReport problem)
      putStrLn ("Entrada: " ++ input)
      putStrLn ("Generado en " ++ outputDir ++ "/: conocimiento.pl, consultas.pl, index.html, reporte_validacion.txt")
      putStrLn (show (length (errors problem)) ++ " error(es), "
                ++ show (length (warnings problem)) ++ " advertencia(s)")
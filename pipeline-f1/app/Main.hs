module Main (main) where

import FileIO (readUTF8, writeUTF8)
import HtmlGen (generateHtml)
import Parser (parseProblem)
import PrologGen (generateKnowledge)
import QueryGen (generateQueries)
import System.Directory (createDirectoryIfMissing, doesFileExist)
import System.Exit (exitFailure)
import System.IO (hPutStrLn, hSetEncoding, stderr, stdout, utf8)
import Validator (renderReport, validate)

inputPath, outputDir :: FilePath
inputPath = "problema.txt"
outputDir = "output"

main :: IO ()
main = do
  hSetEncoding stdout utf8
  exists <- doesFileExist inputPath
  if not exists
    then hPutStrLn stderr ("Error: no se encontró " ++ inputPath) >> exitFailure
    else do
      txt <- readUTF8 inputPath
      let problem = validate (parseProblem txt)
      createDirectoryIfMissing True outputDir
      writeUTF8 (outputDir ++ "/reporte_validacion.txt") (renderReport problem)
      writeUTF8 (outputDir ++ "/conocimiento.pl") (generateKnowledge problem)
      writeUTF8 (outputDir ++ "/consultas.pl") (generateQueries problem)
      writeUTF8 (outputDir ++ "/index.html") (generateHtml problem)
      putStr (renderReport problem)
      putStrLn "Generado en output/: conocimiento.pl, consultas.pl, index.html, reporte_validacion.txt"
module Main (main) where

import FileIO (readUTF8, writeUTF8)
import Parser (parseProblem)
import System.Directory (createDirectoryIfMissing, doesFileExist)
import System.Exit (exitFailure)
import System.IO (hPutStrLn, hSetEncoding, stderr, stdout, utf8)
import Types
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
          report  = renderReport problem
      createDirectoryIfMissing True outputDir
      writeUTF8 (outputDir ++ "/reporte_validacion.txt") report
      putStr report
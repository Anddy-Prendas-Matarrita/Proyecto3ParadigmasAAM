-- | @brief Punto de entrada: orquesta el pipeline Haskell, Prolog y UI.
--
--   Lee el archivo de entrada, construye y valida el modelo intermedio y
--   escribe en la carpeta output: reporte_validacion.txt, conocimiento.pl,
--   consultas.pl e index.html.
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

-- | @brief Carpeta donde se escriben los archivos generados.
outputDir :: FilePath
outputDir = "output"

-- | @brief Obtiene la ruta del archivo de entrada.
--   @param args Argumentos de linea de comandos.
--   @return La primera ruta recibida, o problema.txt por defecto.
inputFrom :: [String] -> FilePath
inputFrom (x : _) = x
inputFrom []      = "problema.txt"

-- | @brief Ejecuta el pipeline completo.
--   Lee el archivo, parsea, valida, genera los cuatro archivos de salida
--   y muestra un resumen en consola. Termina con error si el archivo no existe.
main :: IO ()
main = do
  hSetEncoding stdout utf8
  hSetEncoding stderr utf8
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

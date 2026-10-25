-- | @brief Lectura y escritura de archivos de texto en UTF-8.
--
--   Fuerza la codificacion UTF-8 para que las tildes y la enie se conserven
--   sin depender de la configuracion regional del sistema.
module FileIO (readUTF8, writeUTF8) where

import System.IO

-- | @brief Lee un archivo completo en UTF-8.
--   La lectura es estricta para poder cerrar el archivo de inmediato.
--   @param path Ruta del archivo a leer.
--   @return Contenido completo del archivo.
readUTF8 :: FilePath -> IO String
readUTF8 path = withFile path ReadMode $ \h -> do
  hSetEncoding h utf8
  s <- hGetContents h
  length s `seq` return s

-- | @brief Escribe un texto en un archivo usando UTF-8.
--   Si el archivo existe, se sobrescribe.
--   @param path Ruta del archivo a escribir.
--   @param content Texto a guardar.
writeUTF8 :: FilePath -> String -> IO ()
writeUTF8 path content = withFile path WriteMode $ \h -> do
  hSetEncoding h utf8
  hPutStr h content

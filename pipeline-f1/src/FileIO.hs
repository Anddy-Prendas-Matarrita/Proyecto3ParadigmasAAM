-- | UTF-8 file reading and writing.
module FileIO (readUTF8, writeUTF8) where

import System.IO

readUTF8 :: FilePath -> IO String
readUTF8 path = withFile path ReadMode $ \h -> do
  hSetEncoding h utf8
  s <- hGetContents h
  length s `seq` return s

writeUTF8 :: FilePath -> String -> IO ()
writeUTF8 path content = withFile path WriteMode $ \h -> do
  hSetEncoding h utf8
  hPutStr h content
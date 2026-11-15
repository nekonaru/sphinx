-- | Golden file helpers.
--
-- Golden tests compare exact renderer output against files under
-- @test/golden/@. Paths are relative to the package root, which is
-- where @cabal test@ runs.
module Golden
  ( goldenText
  ) where

import System.Exit (exitFailure)
import System.IO (hPutStrLn, stderr)

-- | Compare @actual@ against the golden file at @path@. Prints a
-- useful diff summary on mismatch.
goldenText :: FilePath -> String -> IO ()
goldenText path actual = do
  expected <- readFile path
  let a = normalize actual
      e = normalize expected
  if a == e
    then pure ()
    else do
      hPutStrLn stderr ("golden mismatch: " ++ path)
      hPutStrLn stderr ("expected: " ++ show (take 120 e))
      hPutStrLn stderr ("actual:   " ++ show (take 120 a))
      exitFailure

normalize :: String -> String
normalize = unlines . map rstrip . lines
  where rstrip = reverse . dropWhile (`elem` " \t\r") . reverse

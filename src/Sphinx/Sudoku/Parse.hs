-- | Parser and validator for sudoku puzzles.
--
-- Accepted input shapes:
--
-- * One line of 81 characters, using '.' or '0' for empty cells.
-- * Nine lines of nine cells each, one cell per character, or nine
--   lines of nine space separated tokens.
--
-- Leading and trailing whitespace and blank lines are ignored.
module Sphinx.Sudoku.Parse
  ( parseSudoku
  ) where

import Data.Char (isSpace)
import qualified Data.Vector as V

import Sphinx.Error (SphinxError(..))
import Sphinx.Sudoku.Types (Grid(..), getCell, units, unitNames)

-- | Parse a sudoku puzzle. Conflicting givens are rejected with a
-- descriptive error; an empty or malformed input is rejected too.
parseSudoku :: String -> Either SphinxError Grid
parseSudoku input
  | null meaningful = Left (SudokuWrongCellCount 0)
  | length meaningful == 1 || length meaningful == 9 =
      parseClean (concatMap stripCells meaningful)
  | otherwise =
      Left (SudokuWrongCellCount (sum (map (length . stripCells) meaningful)))
  where
    meaningful = filter (not . null . stripCells) (linesNorm input)

    -- Normalize CRLF to LF, then split into lines.
    linesNorm = lines . map (\c -> if c == '\r' then '\n' else c)

    -- Remove every space character so token rows and plain rows
    -- are treated the same way.
    stripCells = filter (not . isSpace)

parseClean :: String -> Either SphinxError Grid
parseClean chars
  | length chars /= 81 = Left (SudokuWrongCellCount (length chars))
  | otherwise = do
      cells <- mapDigits chars
      let grid = Grid (V.fromList cells)
      checkConflicts grid
      Right grid

mapDigits :: String -> Either SphinxError [Int]
mapDigits chars = go 0 chars
  where
    go _ [] = Right []
    go i (c:cs) = case digitOf c of
      Just d -> (d:) <$> go (i + 1) cs
      Nothing -> Left (SudokuInvalidChar i c)
    digitOf c
      | c == '.' || c == '0' = Just 0
      | c >= '1' && c <= '9' = Just (fromEnum c - fromEnum '0')
      | otherwise = Nothing

-- | Detect duplicate non zero digits inside any row, column, or box.
checkConflicts :: Grid -> Either SphinxError ()
checkConflicts grid = go (V.toList (V.zip units unitNames))
  where
    go [] = Right ()
    go ((u, name) : rest) =
      let givens = [ getCell grid i | i <- u, getCell grid i /= 0 ]
          dups = [ d | d <- [1 .. 9], length (filter (== d) givens) > 1 ]
      in case dups of
           (d:_) -> Left (SudokuConflict (name ++ " (digit " ++ show d ++ ")"))
           [] -> go rest

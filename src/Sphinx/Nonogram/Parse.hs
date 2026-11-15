-- | Parser for the nonogram text format.
--
-- The format is a list of row clue lines, then a line containing
-- only @---@, then a list of column clue lines. Each clue line is a
-- space separated list of integers. The line @0@ means "no filled
-- cells" (an empty line); anything else must be positive integers.
--
-- Example:
--
-- > 2 2
-- > 7
-- > 7
-- > 5
-- > 3
-- > 1
-- > ---
-- > 2
-- > 4
-- > 5
-- > 5
-- > 5
-- > 4
-- > 2
module Sphinx.Nonogram.Parse
  ( parseNonogram
  ) where

import Data.Char (isSpace)
import Data.List (foldl')

import Sphinx.Error (SphinxError(..))
import Sphinx.Nonogram.Types (Nonogram(..), clueLineLength)

-- | Parse and validate a nonogram puzzle.
parseNonogram :: String -> Either SphinxError Nonogram
parseNonogram input
  | length separatorLines > 1 =
      Left (NonogramFormat "found more than one '---' separator line; exactly one is required")
  | null sectionRows || null sectionCols =
      Left (NonogramFormat "both a row clue section and a column clue section are required (separated by '---')")
  | otherwise = do
      rowClues' <- mapM parseClueLine sectionRows
      colClues' <- mapM parseClueLine sectionCols
      let r = length rowClues'
          c = length colClues'
      mapM_ (checkFits c) (zip [1 ..] rowClues')   -- every row clue fits the column count
      mapM_ (checkFits r) (zip [1 ..] colClues')   -- every column clue fits the row count
      pure (Nonogram rowClues' colClues')
  where
    (sectionRows, sectionCols) = splitOnSeparator (cleanLines input)
    separatorLines = filter (== "---") (cleanLines input)

    cleanLines = filter (not . null) . map trim . lines . map crToLf
    crToLf ch | ch == '\r' = '\n' | otherwise = ch
    trim = dropWhile isSpace . reverse . dropWhile isSpace . reverse

    splitOnSeparator ls =
      let (rs, rest) = span (/= "---") ls
      in case rest of
           (_sep : cs) -> (rs, cs)
           [] -> (rs, [])

-- A clue line is either exactly "0" (empty line) or a list of ASCII
-- digits, each at most six digits long (clues larger than 999999 cells
-- are rejected as absurd).
parseClueLine :: String -> Either SphinxError [Int]
parseClueLine line
  | line == "0" = Right []
  | otherwise = do
      let ws = words line
      if null ws
        then Left (NonogramFormat "found an empty clue line; write 0 for an empty line")
        else mapM parseClueWord ws
  where
    parseClueWord w
      | null w || not (all isAsciiDigit w) =
          Left (NonogramFormat ("invalid clue " ++ show w ++ "; clues must be non negative ASCII digits"))
      | case w of
          ('0' : _) -> True
          _ -> False =
          Left (NonogramFormat ("invalid clue " ++ show w ++ "; write 0 alone for an empty line"))
      | length w > 6 =
          Left (NonogramFormat ("invalid clue " ++ show w ++ "; clues longer than 999999 are not supported"))
      | otherwise = Right (foldl' (\acc ch -> acc * 10 + fromEnum ch - fromEnum '0') 0 w)
    isAsciiDigit ch = ch >= '0' && ch <= '9'

-- A clue list must fit the line it belongs to.
checkFits :: Int -> (Int, [Int]) -> Either SphinxError ()
checkFits lineLen (lineNo, clues)
  | clueLineLength clues > lineLen =
      Left (NonogramInconsistent ("clue list on line " ++ show lineNo ++ " needs "
        ++ show (clueLineLength clues) ++ " cells but the line only has " ++ show lineLen))
  | otherwise = Right ()

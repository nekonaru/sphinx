-- | Terminal rendering for nonogram solutions.
--
-- Filled cells are drawn as a solid block and empty cells as spaces.
-- Column clues are stacked above the grid and row clues sit to the
-- left, both aligned to the cell width.
module Sphinx.Nonogram.Render
  ( renderSolution
  , renderPuzzle
  ) where

import Data.List (intercalate)
import qualified Data.Vector as V

import Sphinx.Nonogram.Types

-- | Render a solved puzzle as a block image with clues.
renderSolution :: Nonogram -> Solution -> String
renderSolution puzzle sol = renderWith puzzle (Just sol)

-- | Render the puzzle with an empty grid (clues only).
renderPuzzle :: Nonogram -> String
renderPuzzle puzzle = renderWith puzzle Nothing

renderWith :: Nonogram -> Maybe Solution -> String
renderWith puzzle mSol = intercalate "\n" (headerLines ++ bodyLines)
  where
    rows = rowClues puzzle
    cols = colClues puzzle
    r = length rows
    c = length cols
    rowClueTexts = [ if null cs then "0" else unwords (map show cs) | cs <- rows ]
    rowClueW = maximum (1 : map length rowClueTexts)
    colW i = maximum (2 : map (length . show) (cols !! i))

    prefix = replicate rowClueW ' ' ++ "| "

    -- Column header: one line per clue depth, stacked top clue first.
    maxDepth = maximum (0 : map length cols)
    headerLines =
      [ prefix ++ concat [ colCell i d | i <- [0 .. c - 1] ]
      | d <- [0 .. maxDepth - 1]
      ]
    colCell i d =
      let col = cols !! i
          offset = length col - maxDepth + d
      in if offset < 0 || offset >= length col
           then replicate (colW i) ' '
           else rightAlign (colW i) (show (col !! offset))

    bodyLines =
      [ pad rowClueW (rowClueTexts !! i) ++ "| " ++ concat cells
      | i <- [0 .. r - 1]
      , let cells = [ cell i j | j <- [0 .. c - 1] ]
      ]
    cell i j =
      let w = colW j
          filled = case mSol of
            Nothing -> False
            Just sol -> cellAt sol i j
      in if filled then replicate w '█' else replicate w ' '

    pad w s = replicate (w - length s) ' ' ++ s
    rightAlign = pad

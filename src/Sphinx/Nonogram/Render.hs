-- | Terminal rendering for nonogram solutions.
--
-- Filled cells are drawn as a solid double-width block and empty
-- cells as a light shade, so the picture is visible on any terminal.
-- Column clues are stacked above the grid and row clues sit to the
-- left, both aligned to the cell width.
module Sphinx.Nonogram.Render
  ( renderSolution
  , renderPuzzle
  ) where

import Data.List (intercalate)

import Sphinx.Nonogram.Types

-- | Render a solved puzzle as a block image with clues.
renderSolution :: Nonogram -> Solution -> String
renderSolution puzzle sol = renderWith puzzle (Just sol)

-- | Render the puzzle with an empty grid (clues only, no picture).
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
    colWidths = [ maximum (2 : map (length . show) cs) | cs <- cols ]

    prefix = replicate rowClueW ' ' ++ " | "

    -- Column header: one line per clue depth, bottom clue closest to
    -- the grid. Cells are joined with single spaces like the body.
    maxDepth = maximum (0 : map length cols)
    headerLines =
      [ prefix ++ intercalate " " [ colCell i d | i <- [0 .. c - 1] ]
      | d <- [0 .. maxDepth - 1]
      ]
    colCell i d =
      let cs = cols !!? i
          k = case cs of
            Just list -> length list - maxDepth + d
            Nothing -> 0
          n = case cs of
            Just list -> show <$> (list !!? k)
            Nothing -> Nothing
      in case n of
           Nothing -> replicate (widthAt i) ' '
           Just s -> rightAlign (widthAt i) s
    widthAt i = case colWidths !!? i of
      Just w -> w
      Nothing -> 2

    bodyLines =
      [ padLeft rowClueW (rowClueTexts !!? i) ++ " | " ++ intercalate " " [ cell i j | j <- [0 .. c - 1] ]
      | i <- [0 .. r - 1]
      ]
    cell i j =
      let w = widthAt j
          filled = case mSol of
            Nothing -> False
            Just sol -> cellAt sol i j
      in if filled then replicate w '█' else replicate w '░'

    padLeft w Nothing = replicate w ' '
    padLeft w (Just s) = replicate (max 0 (w - length s)) ' ' ++ s
    rightAlign w s = replicate (max 0 (w - length s)) ' ' ++ s

-- Total, bounds-checked lookup.
(!!?) :: [a] -> Int -> Maybe a
[] !!? _ = Nothing
(x : _) !!? 0 = Just x
(_ : xs) !!? n
  | n > 0 = xs !!? (n - 1)
  | otherwise = Nothing

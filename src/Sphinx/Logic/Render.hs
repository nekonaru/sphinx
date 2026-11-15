-- | Terminal rendering for logic puzzles.
--
-- Solutions print as a small aligned table: one row per category,
-- one column per house. Unsolved puzzles print the same shape with
-- every cell as a question mark.
module Sphinx.Logic.Render
  ( renderSolution
  , renderPuzzle
  ) where

import Data.List (intercalate)
import Data.Maybe (fromMaybe)
import qualified Data.Vector as V

import Sphinx.Logic.DSL

-- | Render a solved puzzle as an aligned table.
renderSolution :: LogicPuzzle -> LogicSolution -> String
renderSolution puzzle solution = intercalate "\n" (header : body)
  where
    cats = V.toList (logicCategories puzzle)
    n = houseCount puzzle
    rows = V.toList (unLogicSolution solution)

    cell i j = fromMaybe "?" (rows !!? i >>= (V.!? j))
    labelWidth = maximum (1 : map (length . categoryName) cats)
    colWidth j = maximum (length ("House " ++ show (j + 1)) : [ length (cell i j) | i <- [0 .. length rows - 1] ])
    colWidths = [ colWidth j | j <- [0 .. n - 1] ]

    labelCell s = padRight labelWidth s ++ "  "
    cellCell j s = let w = fromMaybe 2 (colWidths !!? j) in padLeft w s ++ "  "

    header = labelCell "" ++ concat [ cellCell j ("House " ++ show (j + 1)) | j <- [0 .. n - 1] ]
    body =
      [ labelCell (categoryName cat) ++ concat [ cellCell j (cell i j) | j <- [0 .. n - 1] ]
      | (i, cat) <- zip [0 ..] cats
      ]

padRight :: Int -> String -> String
padRight w s = s ++ replicate (max 0 (w - length s)) ' '

padLeft :: Int -> String -> String
padLeft w s = replicate (max 0 (w - length s)) ' ' ++ s

-- Safe list indexing.
(!!?) :: [a] -> Int -> Maybe a
[] !!? _ = Nothing
(x : _) !!? 0 = Just x
(_ : xs) !!? n
  | n > 0 = xs !!? (n - 1)
  | otherwise = Nothing

-- | Render an unsolved puzzle as the same table, with question marks.
renderPuzzle :: LogicPuzzle -> String
renderPuzzle puzzle =
  let cats = V.toList (logicCategories puzzle)
      n = houseCount puzzle
      blankRows = map (const (V.replicate n "?")) cats
      solution = LogicSolution (V.fromList blankRows)
  in renderSolution puzzle solution

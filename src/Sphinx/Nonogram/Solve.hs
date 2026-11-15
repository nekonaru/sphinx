-- | Nonogram solver: line solving with propagation to a fixpoint,
-- then branching on the line with the fewest remaining options.
--
-- Cells are tracked as 'Maybe Bool' (@Nothing@ unknown). Options for
-- a line are enumerated from the clues and filtered by the known
-- cells; when every remaining option agrees on a cell, that cell
-- becomes known. This is repeated until nothing changes, then the
-- search branches on the hardest line.
module Sphinx.Nonogram.Solve
  ( SolveStats(..)
  , solveUpTo
  , solveWithStats
  ) where

import Data.List (minimumBy, transpose)
import Data.Maybe (fromMaybe)
import Data.Ord (comparing)
import qualified Data.Vector as V

import Sphinx.Class (Puzzle(..))
import Sphinx.Nonogram.Line (lineOptions)
import Sphinx.Nonogram.Parse (parseNonogram)
import qualified Sphinx.Nonogram.Render as NRender
import Sphinx.Nonogram.Types

-- | Statistics about one solve, reported by @--steps@.
data SolveStats = SolveStats
  { guesses :: Int    -- ^ branch decisions on the path to the first solution
  , deadEnds :: Int   -- ^ option branches that failed before that solution
  } deriving (Eq, Show)

-- Internal grid: rows of Maybe Bool.
type MGrid = V.Vector (V.Vector (Maybe Bool))

initialGrid :: Nonogram -> MGrid
initialGrid puzzle =
  V.replicate (gridRows puzzle) (V.replicate (gridCols puzzle) Nothing)

-- | Find up to @n@ solutions.
solveUpTo :: Int -> Nonogram -> [Solution]
solveUpTo n puzzle = take n (map fst (search puzzle (initialGrid puzzle)))

-- | Solve and also report statistics about the search.
solveWithStats :: Nonogram -> Maybe (Solution, SolveStats)
solveWithStats puzzle = case search puzzle (initialGrid puzzle) of
  (first : _) -> Just first
  [] -> Nothing

-- Backtracking search with propagation. Solutions carry the stats of
-- the branch path that produced them.
search :: Nonogram -> MGrid -> [(Solution, SolveStats)]
search puzzle g = case propagate puzzle g of
  Nothing -> []
  Just g'
    | isComplete g' -> [(toSolution g', SolveStats 0 0)]
    | otherwise -> case bestLine puzzle g' of
        Nothing -> []
        Just (isRow, idx, options) -> tryBranch puzzle g' isRow idx options

tryBranch :: Nonogram -> MGrid -> Bool -> Int -> [[Bool]] -> [(Solution, SolveStats)]
tryBranch puzzle g isRow idx options = go options 0
  where
    go [] _ = []
    go (opt : rest) dead =
      let child = if isRow then setRow g idx opt else setCol g idx opt
      in case search puzzle child of
           [] -> go rest (dead + 1)
           found ->
             [ (sol, SolveStats (guesses st + 1) (deadEnds st + dead))
             | (sol, st) <- found
             ] ++ go rest (dead + 1)

-- Propagate line constraints to a fixpoint.
propagate :: Nonogram -> MGrid -> Maybe MGrid
propagate puzzle g =
  let (g', changed, contradiction) = propagateOnce puzzle g
  in if contradiction
       then Nothing
       else if changed
         then propagate puzzle g'
         else Just g'

propagateOnce :: Nonogram -> MGrid -> (MGrid, Bool, Bool)
propagateOnce puzzle g =
  let (g1, ch1, ct1) = propagateLines puzzle gridCols' (rowClues puzzle) g
      gt = transposeGrid g1
      (g2t, ch2, ct2) = propagateLines puzzle gridRows' (colClues puzzle) gt
  in (transposeGrid g2t, ch1 || ch2, ct1 || ct2)
  where
    gridCols' = gridCols puzzle
    gridRows' = gridRows puzzle

propagateLines :: Nonogram -> Int -> [[Int]] -> MGrid -> (MGrid, Bool, Bool)
propagateLines _ lineLen clues g0 = foldl' step (g0, False, False) (zip [0 ..] clues)
  where
    step (gg, ch, ct) (idx, lineClues)
      | ct = (gg, ch, ct)
      | otherwise =
          let known = V.toList (gg V.! idx)
              options = lineOptions lineLen lineClues known
          in case options of
               [] -> (gg, ch, True)
               _ ->
                 let merged = V.fromList
                       [ mergeCell known cellValues
                       | (known, cellValues) <- zip known (transpose options)
                       ]
                     changedNow = or
                       [ changedCell a b
                       | (a, b) <- zip known (V.toList merged)
                       ]
                 in (gg V.// [(idx, merged)], ch || changedNow, False)

isComplete :: MGrid -> Bool
isComplete = V.all (V.all isJust')
  where
    isJust' (Just _) = True
    isJust' Nothing = False

toSolution :: MGrid -> Solution
toSolution = Solution . V.map (V.map (fromMaybe False))

transposeGrid :: MGrid -> MGrid
transposeGrid = V.fromList . map V.fromList . transpose . map V.toList . V.toList

setRow :: MGrid -> Int -> [Bool] -> MGrid
setRow g r opt = g V.// [(r, V.fromList (map Just opt))]

setCol :: MGrid -> Int -> [Bool] -> MGrid
setCol g c opt =
  V.fromList [ row V.// [(c, Just v)] | (row, v) <- zip (V.toList g) opt ]

mergeCell :: Maybe Bool -> [Bool] -> Maybe Bool
mergeCell known cellValues = case known of
  Just v -> Just v
  Nothing
    | all id cellValues -> Just True
    | not (any id cellValues) -> Just False
    | otherwise -> Nothing

changedCell :: Maybe Bool -> Maybe Bool -> Bool
changedCell Nothing (Just _) = True
changedCell _ _ = False

-- Choose the unsolved line with the fewest remaining options, if any.
-- Returns (isRow, index, options).
bestLine :: Nonogram -> MGrid -> Maybe (Bool, Int, [[Bool]])
bestLine puzzle g =
  let rows =
        [ (True, r, options)
        | (r, clues) <- zip [0 ..] (rowClues puzzle)
        , hasUnknown (g V.! r)
        , let options = lineOptions (gridCols puzzle) clues (V.toList (g V.! r))
        , not (null options)
        ]
      gt = transposeGrid g
      cols =
        [ (False, c, options)
        | (c, clues) <- zip [0 ..] (colClues puzzle)
        , let col = gt V.! c
        , hasUnknown col
        , let options = lineOptions (gridRows puzzle) clues (V.toList col)
        , not (null options)
        ]
      candidates = rows ++ cols
  in case candidates of
       [] -> Nothing
       _ -> Just (minimumBy (comparing (\(_, _, o) -> length o)) candidates)
  where
    hasUnknown = V.any (== Nothing)

-- | Uniform 'Puzzle' interface for nonograms.
instance Puzzle Nonogram where
  type Solution Nonogram = Solution
  parsePuzzle = parseNonogram
  solveLimit = solveUpTo
  renderSolution puzzle sol = NRender.renderSolution puzzle sol
  renderPuzzle = NRender.renderPuzzle

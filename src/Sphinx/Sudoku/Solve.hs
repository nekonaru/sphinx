-- | Sudoku solver: constraint propagation (naked and hidden singles)
-- followed by backtracking with a minimum remaining values heuristic.
--
-- The solver is pure. Every solver entry point returns at most the
-- requested number of solutions; uniqueness checking is therefore
-- just @solveUpTo 2@.
module Sphinx.Sudoku.Solve
  ( Step(..)
  , renderStep
  , solveUpTo
  , solveWithSteps
  , candidateMask
  , propagate
  ) where

import Data.Bits ((.|.), (.&.), shiftL, complement, popCount, testBit)
import Data.List (foldl', minimumBy)
import Data.Ord (comparing)
import qualified Data.Vector as V

import Sphinx.Sudoku.Types

-- | A single deduction made by the solver, used by the @--steps@ mode.
data Step
  = -- | A cell had exactly one possible digit.
    NakedSingle
      { stepPos :: Int
      , stepDigit :: Int
      }
  | -- | A digit could only go in one cell of its unit.
    HiddenSingle
      { stepPos :: Int
      , stepDigit :: Int
      , stepUnit :: String
      }
  | -- | The solver branched on a cell with several candidates.
    Guess
      { stepPos :: Int
      , stepDigit :: Int
      }
  deriving (Eq, Show)

-- | Render a step as one human readable sentence (Bahasa Indonesia).
renderStep :: Int -> Step -> String
renderStep n st = case st of
  NakedSingle i d ->
    show n ++ ". R" ++ show (rowIndex i + 1) ++ "C" ++ show (colIndex i + 1)
      ++ " = " ++ show d ++ " (naked single: satu-satunya kandidat yang tersisa)"
  HiddenSingle i d unit ->
    show n ++ ". R" ++ show (rowIndex i + 1) ++ "C" ++ show (colIndex i + 1)
      ++ " = " ++ show d ++ " (hidden single: satu-satunya tempat untuk " ++ show d ++ " di " ++ unit ++ ")"
  Guess i d ->
    show n ++ ". Coba R" ++ show (rowIndex i + 1) ++ "C" ++ show (colIndex i + 1)
      ++ " = " ++ show d ++ " (tebakan, pencarian backtracking)"

-- | Bit mask of the candidate digits for a cell. Bit (d-1) is set
-- when digit d is still possible. Occupied cells have mask 0.
candidateMask :: Grid -> Int -> Int
candidateMask g i
  | getCell g i /= 0 = 0
  | otherwise = allDigits .&. complement (usedMask g i)
  where
    allDigits = (1 `shiftL` 9) - 1

-- Bits for the digits already placed in any peer of cell i.
usedMask :: Grid -> Int -> Int
usedMask g i = foldl' (.|.) 0 [ bitFor (getCell g j) | j <- peers V.! i ]
  where
    bitFor d
      | d >= 1 && d <= 9 = 1 `shiftL` (d - 1)
      | otherwise = 0

-- | Digits set in a mask, as a list in ascending order.
maskDigits :: Int -> [Int]
maskDigits m = [ d | d <- [1 .. 9], testBit m (d - 1) ]

-- | First naked single: an empty cell with exactly one candidate.
findNakedSingle :: Grid -> Maybe (Int, Int)
findNakedSingle g = go 0
  where
    go i
      | i >= 81 = Nothing
      | getCell g i /= 0 = go (i + 1)
      | otherwise =
          let m = candidateMask g i
          in if popCount m == 1
               then Just (i, headDigit m)
               else go (i + 1)
    headDigit m = case maskDigits m of
      (d : _) -> d
      [] -> 0  -- unreachable: mask has exactly one bit

-- | First hidden single: a digit with exactly one place in its unit.
findHiddenSingle :: Grid -> Maybe (Int, Int, String)
findHiddenSingle g = go (zip (V.toList units) (V.toList unitNames))
  where
    go [] = Nothing
    go ((u, name) : rest) = case hiddenInUnit u of
      Just (i, d) -> Just (i, d, name)
      Nothing -> go rest
    hiddenInUnit u = goDigit 1
      where
        goDigit d
          | d > 9 = Nothing
          | any (\i -> getCell g i == d) u = goDigit (d + 1)  -- already placed
          | otherwise =
              let spots = [ i | i <- u, getCell g i == 0, testBit (candidateMask g i) (d - 1) ]
              in case spots of
                   [i] -> Just (i, d)
                   _ -> goDigit (d + 1)

-- | Apply naked and hidden singles until no more can be applied.
-- Returns 'Nothing' when a contradiction is found (an empty cell
-- with no candidates left).
propagate :: Grid -> Maybe (Grid, [Step])
propagate g0 = go g0 []
  where
    go g acc =
      case findNakedSingle g of
        Just (i, d) -> go (setCell i d g) (NakedSingle i d : acc)
        Nothing -> case findHiddenSingle g of
          Just (i, d, unit) -> go (setCell i d g) (HiddenSingle i d unit : acc)
          Nothing ->
            if hasContradiction g
              then Nothing
              else Just (g, reverse acc)
    hasContradiction g = any (\i -> getCell g i == 0 && candidateMask g i == 0) [0 .. 80]

-- | The empty cell with the fewest candidates, if any.
findMRV :: Grid -> Maybe (Int, Int)
findMRV g =
  let empties = [ (i, popCount (candidateMask g i)) | i <- [0 .. 80], getCell g i == 0 ]
  in case empties of
       [] -> Nothing
       _ -> Just (minimumBy (comparing snd) empties)

-- | Backtracking search with constraint propagation. Lazily returns
-- solutions; 'solveUpTo' truncates the list.
search :: Grid -> [(Grid, [Step])]
search g = case propagate g of
  Nothing -> []
  Just (g', st) -> case findMRV g' of
    Nothing -> [(g', st)]
    Just (i, _) ->
      let m = candidateMask g' i
      in [ (sol, st ++ Guess i d : rest)
         | d <- maskDigits m
         , (sol, rest) <- search (setCell i d g')
         ]

-- | Find up to @n@ solutions.
solveUpTo :: Int -> Grid -> [Grid]
solveUpTo n g = take n [ sol | (sol, _) <- search g ]

-- | Solve a puzzle and also report the deduction steps in order.
solveWithSteps :: Grid -> Maybe (Grid, [Step])
solveWithSteps g = case search g of
  (sol, steps) : _ -> Just (sol, steps)
  [] -> Nothing



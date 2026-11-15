-- | Random sudoku generator with a guaranteed unique solution.
--
-- Generation works in two phases:
--
-- 1. Build a complete, valid grid by backtracking with a shuffled
--    digit order driven by a splitmix64 seeded PRNG.
-- 2. Dig holes: visit cells in a shuffled order and remove a digit
--    only while the puzzle keeps exactly one solution.
--
-- The seed makes generation reproducible, which keeps tests honest.
module Sphinx.Sudoku.Generate
  ( Difficulty(..)
  , parseDifficulty
  , difficultyName
  , generateSudoku
  , splitmix64
  ) where

import Data.Bits (xor, shiftR)
import Data.Char (toLower)
import Data.Word (Word64)
import qualified Data.Vector as V

import Sphinx.Sudoku.Solve (solveUpTo)
import Sphinx.Sudoku.Types

-- | Difficulty presets, controlling how many givens remain.
data Difficulty
  = Easy     -- ^ 40 givens
  | Medium   -- ^ 32 givens
  | Hard     -- ^ 26 givens
  deriving (Eq, Show, Enum, Bounded)

-- | Parse a difficulty name.
parseDifficulty :: String -> Maybe Difficulty
parseDifficulty s = case map toLower s of
  "easy" -> Just Easy
  "medium" -> Just Medium
  "hard" -> Just Hard
  _ -> Nothing

-- | Show a difficulty the same way the CLI accepts it.
difficultyName :: Difficulty -> String
difficultyName d = case d of
  Easy -> "easy"
  Medium -> "medium"
  Hard -> "hard"

-- Target number of givens per difficulty.
givenTarget :: Difficulty -> Int
givenTarget d = case d of
  Easy -> 40
  Medium -> 32
  Hard -> 26

-- | A tiny, fast, seedable PRNG (splitmix64). Enough for shuffling;
-- not suitable for anything security related.
splitmix64 :: Word64 -> [Word64]
splitmix64 seed = go seed
  where
    go s = let s' = s + 0x9e3779b97f4a7c15
               z = s'
               z1 = (z `xor` (z `shiftR` 30)) * 0xbf58476d1ce4e5b9
               z2 = (z1 `xor` (z1 `shiftR` 27)) * 0x94d049bb133111eb
               z3 = z2 `xor` (z2 `shiftR` 31)
           in z3 : go s'

-- Deterministic Fisher-Yates shuffle driven by an infinite PRNG stream.
shuffleWith :: [Word64] -> [a] -> [a]
shuffleWith rng xs = go rng (V.fromList xs)
  where
    go _ v | V.null v = []
    go (r:rs) v =
      let n = V.length v
          i = fromIntegral (r `mod` fromIntegral n)
          x = v V.! i
          v' = v V.// [(i, v V.! (n - 1)), (n - 1, v V.! i)]
      in x : go rs (V.slice 0 (n - 1) v')
    go [] v = V.toList v

-- | A deterministic backtracking fill that respects the PRNG stream.
fillGrid :: [Word64] -> Grid
fillGrid rng = case solveOrdered rng emptyGrid of
  Just g -> g
  Nothing -> emptyGrid  -- unreachable for an empty grid
  where
    solveOrdered _ g | isSolved g = Just g
    solveOrdered r g =
      case firstEmpty g of
        Nothing -> Just g
        Just i ->
          let digits = shuffleWith r [1 .. 9]
          in firstJust [ solveOrdered r' (setCell i d g)
                       | (d, r') <- zip digits (drop 9 r) ]
    firstEmpty g = go' 0
      where
        go' i
          | i >= 81 = Nothing
          | getCell g i == 0 = Just i
          | otherwise = go' (i + 1)
    firstJust = foldr (\m rest -> case m of Just x -> Just x; Nothing -> rest) Nothing

-- | Generate a puzzle with a unique solution.
generateSudoku :: Difficulty -> Word64 -> Grid
generateSudoku difficulty seed = dig (shuffleWith rng [ 0 .. 80 ]) full
  where
    full = fillGrid (splitmix64 seed)
    rng = splitmix64 (seed + 1)

    dig [] g = g
    dig (i : is) g
      | givens g <= givenTarget difficulty = g
      | otherwise =
          let saved = getCell g i
              g' = setCell i 0 g
          in if length (solveUpTo 2 g') == 1
               then dig is g'
               else dig is g

    givens g = length [ i | i <- [0 .. 80], getCell g i /= 0 ]

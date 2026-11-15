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
    go s =
      let s' = s + 0x9e3779b97f4a7c15
          z1 = (s' `xor` (s' `shiftR` 30)) * 0xbf58476d1ce4e5b9
          z2 = (z1 `xor` (z1 `shiftR` 27)) * 0x94d049bb133111eb
          z3 = z2 `xor` (z2 `shiftR` 31)
      in z3 : go s'

-- Deterministic Fisher-Yates shuffle driven by the PRNG stream.
-- Returns the shuffled list and the unconsumed remainder of the stream.
shuffleWith :: [Word64] -> [a] -> ([a], [Word64])
shuffleWith stream xs = go stream (V.fromList xs) []
  where
    go s v acc
      | V.null v = (reverse acc, s)
    go (r : rs) v acc =
      let n = V.length v
          i = fromIntegral (r `mod` fromIntegral n)
          x = v V.! i
          v' = v V.// [(i, v V.! (n - 1)), (n - 1, v V.! i)]
      in go rs (V.slice 0 (n - 1) v') (x : acc)
    go [] v acc = (reverse acc ++ V.toList v, [])  -- stream shorter than v; not expected

-- | A deterministic backtracking fill that respects the PRNG stream.
-- Digits are only placed where they cannot conflict with the peers
-- already assigned, which prunes the search hard.
fillGrid :: [Word64] -> Grid
fillGrid rng = case go rng emptyGrid of
  Just g -> g
  Nothing -> emptyGrid  -- unreachable from the empty grid
  where
    go :: [Word64] -> Grid -> Maybe Grid
    go r g
      | isSolved g = Just g
      | otherwise =
          case firstEmpty g of
            Nothing -> Nothing  -- full but invalid: dead end
            Just i ->
              let (digits, after) = shuffleWith r [1 .. 9]
              in tryAll g i after (zip [0 ..] digits)

    tryAll :: Grid -> Int -> [Word64] -> [(Int, Int)] -> Maybe Grid
    tryAll _ _ _ [] = Nothing
    tryAll g i after ((k, d) : rest)
      | not (validPlacement g i d) = tryAll g i after rest
      | otherwise = case go (drop k after) (setCell i d g) of
          Just g' -> Just g'
          Nothing -> tryAll g i after rest

    firstEmpty g = goEmpty 0
      where
        goEmpty i
          | i >= 81 = Nothing
          | getCell g i == 0 = Just i
          | otherwise = goEmpty (i + 1)

-- Peers of cell i must not already hold digit d.
validPlacement :: Grid -> Int -> Int -> Bool
validPlacement g i d = all (\j -> getCell g j /= d) (peers V.! i)

-- | Generate a puzzle with a unique solution.
generateSudoku :: Difficulty -> Word64 -> Grid
generateSudoku difficulty seed = dig cellOrder full
  where
    full = fillGrid (splitmix64 seed)
    cellOrder = fst (shuffleWith (splitmix64 (seed + 1)) [0 .. 80])

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

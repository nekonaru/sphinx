{-# LANGUAGE ScopedTypeVariables #-}

-- | Sphinx test suite: unit tests for parsing and solving, property
-- tests for solver guarantees, and golden tests for the renderers.
module Main (main) where

import Data.List (intercalate)
import Data.Word (Word64)
import qualified Data.Vector as V
import Test.QuickCheck
import Test.Hspec

import Golden (goldenText)

import Sphinx.Class (Puzzle(..), firstSolution, isUnique)
import Sphinx.Error (SphinxError(..))
import qualified Sphinx.Nonogram.Line as NLine
import Sphinx.Nonogram.Parse (parseNonogram)
import qualified Sphinx.Nonogram.Render as NRender
import qualified Sphinx.Nonogram.Solve as NS
import Sphinx.Nonogram.Types (Nonogram(..), gridRows, gridCols, filledCount)
import qualified Sphinx.Nonogram.Types as NT
import qualified Sphinx.Logic.DSL as LD
import Sphinx.Logic.Puzzle ()
import qualified Sphinx.Logic.Render as LRender
import qualified Sphinx.Sudoku.Generate as Gen
import Sphinx.Sudoku.Puzzle ()
import Sphinx.Nonogram.Puzzle ()
import qualified Sphinx.Sudoku.Parse as SP
import Sphinx.Sudoku.Render (renderGrid)
import Sphinx.Sudoku.Solve (Step(..), solveUpTo, solveWithSteps)
import Sphinx.Sudoku.Types

-- The classic Wikipedia example puzzle and its known solution.
easyPuzzle :: String
easyPuzzle = "530070000600195000098000060800060003400803001700020006060000280000419005000080079"

main :: IO ()
main = hspec $ do
  parseSpec
  sudokuSolveSpec
  sudokuPropertySpec
  generateSpec
  nonogramSpec
  logicSpec
  classSpec
  fuzzSpec
  goldenSpec

parseSpec :: Spec
parseSpec = describe "Sudoku parsing" $ do
  it "parses an 81 character single line" $
    case SP.parseSudoku easyPuzzle of
      Right _ -> True `shouldBe` True
      Left e -> expectationFailure (show e)

  it "accepts dots and zeros as empty cells, equivalently" $
    SP.parseSudoku (map (\c -> if c == '.' then '0' else c) easyPuzzle)
      `shouldBe` SP.parseSudoku easyPuzzle

  it "rejects input of the wrong length" $
    SP.parseSudoku "123" `shouldBe` Left (SudokuWrongCellCount 3)

  it "rejects invalid characters with position" $
    SP.parseSudoku (replicate 40 '.' ++ "x" ++ replicate 40 '.')
      `shouldBe` Left (SudokuInvalidChar 40 'x')

  it "rejects duplicate givens in a row" $
    SP.parseSudoku ("11" ++ replicate 79 '.') `shouldBe` Left (SudokuConflict "baris 1 (digit 1)")

  it "rejects duplicate givens in a box" $
    SP.parseSudoku ("1........" ++ ".1......." ++ replicate 63 '.') `shouldBe` Left (SudokuConflict "kotak 1 (digit 1)")

  it "rejects non-ASCII Unicode digits" $
    SP.parseSudoku ("7" ++ "٣" ++ replicate 79 '.') `shouldBe` Left (SudokuInvalidChar 1 '٣')

  it "parses the 9-line format" $
    SP.parseSudoku (unlines ["53..7....","6..195...",".98....6.","8...6...3","4..8.3..1","7...2...6",".6....28.","...419..5","....8..79"])
      `shouldBe` SP.parseSudoku easyPuzzle

sudokuSolveSpec :: Spec
sudokuSolveSpec = describe "Sudoku solving" $ do
  it "solves the classic easy puzzle" $
    case SP.parseSudoku easyPuzzle of
      Left e -> expectationFailure (show e)
      Right g -> do
        let solved = headOrFail (solveUpTo 1 g)
        renderGrid solved `shouldBe` expectedEasyGrid

  it "solves a generated hard puzzle" $ do
    let puzzle = Gen.generateSudoku Gen.Hard 1234
    case solveUpTo 1 puzzle of
      (sol : _) -> do
        isSolved sol `shouldBe` True
        respectsGivens puzzle sol `shouldBe` True
      [] -> expectationFailure "no solution found"

  it "detects that a nearly empty board has multiple solutions" $
    case SP.parseSudoku (replicate 81 '.') of
      Left e -> expectationFailure (show e)
      Right g -> length (solveUpTo 2 g) `shouldBe` 2

  it "reports no solution when the puzzle is unsatisfiable" $ do
    -- Mutated from the classic easy puzzle: the first given (position
    -- 0) changed to a digit that does not clash in its row, column or
    -- box, yet makes the puzzle unsatisfiable. Verified by the solver.
    let unsat = "130070000600195000098000060800060003400803001700020006060000280000419005000080079"
    case SP.parseSudoku unsat of
      Left _ -> expectationFailure "candidate unsatisfiable puzzle was rejected at parse time"
      Right g -> solveUpTo 1 g `shouldBe` []

  it "steps fill only empty cells, always with the solution's digits" $
    case SP.parseSudoku easyPuzzle of
      Left e -> expectationFailure (show e)
      Right g -> case solveWithSteps g of
        Nothing -> expectationFailure "no solution found"
        Just (sol, steps) -> do
          isSolved sol `shouldBe` True
          length steps `shouldSatisfy` (> 0)
          all (digitMatches sol) steps `shouldBe` True
          all (wasEmpty g) steps `shouldBe` True

sudokuPropertySpec :: Spec
sudokuPropertySpec = describe "Sudoku solver properties" $
  it "generated puzzles always solve to a grid respecting the givens" $
    withMaxSuccess 4 $ property $ \(seed :: Word64) ->
      let grid = Gen.generateSudoku Gen.Easy seed
      in case solveUpTo 1 grid of
           (sol : _) -> isSolved sol && respectsGivens grid sol
           [] -> False

generateSpec :: Spec
generateSpec = describe "Sudoku generation" $ do
  it "generates puzzles with a unique solution" $ do
    let puzzle = Gen.generateSudoku Gen.Medium 1234
    length (solveUpTo 2 puzzle) `shouldBe` 1

  it "is deterministic for a fixed seed" $
    Gen.generateSudoku Gen.Hard 99 `shouldBe` Gen.generateSudoku Gen.Hard 99

  it "parses difficulty names case insensitively" $ do
    Gen.parseDifficulty "EASY" `shouldBe` Just Gen.Easy
    Gen.parseDifficulty "nope" `shouldBe` Nothing

nonogramSpec :: Spec
nonogramSpec = describe "Nonogram" $ do
  it "rejects clues whose block cannot fit the line" $
    case parseNonogram (unlines ["3", "---", "2"]) of
      Left _ -> True `shouldBe` True  -- row clue needs 3 of 1 column: rejected
      Right _ -> expectationFailure "expected a parse failure"

  it "rejects absurd clue tokens without crashing" $
    case parseNonogram (unlines ["99999999", "---", "1"]) of
      Left _ -> True `shouldBe` True
      Right _ -> expectationFailure "expected a parse failure"

  it "rejects multiple '---' separators" $
    case parseNonogram (unlines ["1", "---", "1", "---", "1"]) of
      Left _ -> True `shouldBe` True
      Right _ -> expectationFailure "expected a parse failure"

  it "enumerates 3 arrangements for a single block of 1 in length 3" $
    NLine.arrangements 3 [1] `shouldBe`
      [ [True, False, False], [False, True, False], [False, False, True] ]

  it "enumerates the only filling for full coverage" $
    NLine.arrangements 3 [3] `shouldBe` [ [True, True, True] ]

  it "enumerates the empty filling for empty clues" $
    NLine.arrangements 4 [] `shouldBe` [ [False, False, False, False] ]

  it "enumerates exactly the three fillings for 2+2 in length 6" $
    NLine.arrangements 6 [2, 2] `shouldBe`
      [ [True, True, False, True, True, False]
      , [True, True, False, False, True, True]
      , [False, True, True, False, True, True]
      ]

  it "parses the PRD example format" $ do
    let input = unlines ["2 2", "7", "7", "5", "3", "1", "---", "2", "4", "5", "5", "5", "4", "2"]
    case parseNonogram input of
      Left e -> expectationFailure (show e)
      Right p -> do
        gridRows p `shouldBe` 6
        gridCols p `shouldBe` 7

  it "solves the heart puzzle" $ do
    let heart = unlines ["2 2", "7", "7", "5", "3", "1", "---", "2", "4", "5", "5", "5", "4", "2"]
    case parseNonogram heart of
      Left e -> expectationFailure (show e)
      Right p -> case NS.solveUpTo 1 p of
        (sol : _) -> filledCount sol `shouldBe` 27
        [] -> expectationFailure "no solution found"

  it "reports unsolvable puzzles without crashing" $ do
    let impossible = unlines ["2", "0", "2", "---", "2", "0", "2"]
    case parseNonogram impossible of
      Left e -> expectationFailure ("expected parse to succeed, got: " ++ show e)
      Right p -> NS.solveUpTo 1 p `shouldBe` []

classSpec :: Spec
classSpec = describe "Puzzle typeclass" $ do
  it "solves sudoku through the shared interface" $
    case parsePuzzle easyPuzzle :: Either SphinxError Grid of
      Left e -> expectationFailure (show e)
      Right p -> firstSolution p `shouldSatisfy` isJustOk

  it "reports uniqueness through the shared interface" $
    case parsePuzzle easyPuzzle :: Either SphinxError Grid of
      Left e -> expectationFailure (show e)
      Right p -> isUnique p `shouldBe` True

  it "solves nonograms through the shared interface" $
    case parsePuzzle heartPuzzle :: Either SphinxError Nonogram of
      Left e -> expectationFailure (show e)
      Right p -> firstSolution p `shouldSatisfy` isJustOk

fuzzSpec :: Spec
fuzzSpec = describe "Hostile input fuzzing" $ do
  it "sudoku parser never crashes on arbitrary strings" $
    property $ \(s :: String) ->
      case SP.parseSudoku s of
        Left _ -> True
        Right _ -> True

  it "nonogram parser never crashes on arbitrary strings" $
    property $ \(s :: String) ->
      case parseNonogram s of
        Left _ -> True
        Right _ -> True

  it "logic parser never crashes on arbitrary strings" $
    property $ \(s :: String) ->
      case LD.parseLogic s of
        Left _ -> True
        Right _ -> True

zebraTiny :: String
zebraTiny = unlines
  [ "houses: 3"
  , "category name: Alice Bob Carol"
  , "category drink: tea coffee juice"
  , "category color: red green blue"
  , "clues:"
  , "pos Alice 1"
  , "eq tea green"
  , "notsame Bob tea"
  , "eq Carol juice"
  , "leftof red juice"
  ]

zebraUnderconstrained :: String
zebraUnderconstrained = unlines
  [ "houses: 3"
  , "category name: Alice Bob Carol"
  , "category drink: tea coffee juice"
  , "category color: red green blue"
  , "clues:"
  , "eq tea green"
  , "notsame Bob tea"
  , "eq Carol juice"
  , "leftof red juice"
  ]

logicSpec :: Spec
logicSpec = describe "Logic (zebra) puzzles" $ do
  it "parses a valid puzzle" $
    case LD.parseLogic zebraTiny of
      Right _ -> True `shouldBe` True
      Left e -> expectationFailure (show e)

  it "rejects a clue with an unknown value" $
    case LD.parseLogic (replaceLine "eq tea green" "eq zzz green" zebraTiny) of
      Left (LogicFormat _) -> True `shouldBe` True
      Left _ -> expectationFailure "expected a LogicFormat error"
      Right _ -> expectationFailure "expected a parse failure"

  it "rejects a clue relating values of the same category" $
    case LD.parseLogic (replaceLine "eq tea green" "eq Alice Bob" zebraTiny) of
      Left (LogicFormat _) -> True `shouldBe` True
      Left _ -> expectationFailure "expected a LogicFormat error"
      Right _ -> expectationFailure "expected a parse failure"

  it "rejects a bogus overflowing house number" $
    case LD.parseLogic ("houses: 18446744073709551618\ncategory name: Alice Bob\nclues:\npos Alice 1\n") of
      Left (LogicFormat _) -> True `shouldBe` True
      Left _ -> expectationFailure "expected a LogicFormat error"
      Right _ -> expectationFailure "expected a parse failure"

  it "rejects a bogus overflowing pos house number" $
    case LD.parseLogic (replaceLine "pos Alice 1" "pos Alice 18446744073709551617" zebraTiny) of
      Left (LogicFormat _) -> True `shouldBe` True
      Left _ -> expectationFailure "expected a LogicFormat error"
      Right _ -> expectationFailure "expected a parse failure"

  it "rejects an out-of-range pos house number" $
    case LD.parseLogic (replaceLine "pos Alice 1" "pos Alice 5" zebraTiny) of
      Left (LogicFormat _) -> True `shouldBe` True
      Left _ -> expectationFailure "expected a LogicFormat error"
      Right _ -> expectationFailure "expected a parse failure"

  it "rejects duplicate category names" $
    case LD.parseLogic (unlines ["houses: 2", "category name: Alice Bob", "category name: Carol Dave", "clues:", "pos Alice 1"]) of
      Left (LogicFormat _) -> True `shouldBe` True
      Left _ -> expectationFailure "expected a LogicFormat error"
      Right _ -> expectationFailure "expected a parse failure"

  it "rejects duplicate values across categories" $
    case LD.parseLogic (unlines ["houses: 2", "category name: Alice Bob", "category drink: tea Alice", "clues:", "pos Alice 1"]) of
      Left (LogicFormat _) -> True `shouldBe` True
      Left _ -> expectationFailure "expected a LogicFormat error"
      Right _ -> expectationFailure "expected a parse failure"

  it "parses CRLF line endings" $
    case LD.parseLogic (concatMap crlf zebraTiny) of
      Right _ -> True `shouldBe` True
      Left e -> expectationFailure (show e)

  it "solves examples/zebra-einstein.txt to the golden output" $ do
    zebraExampleText <- readFile "examples/zebra-einstein.txt"
    case LD.parseLogic zebraExampleText of
      Left e -> expectationFailure (show e)
      Right p -> case LD.solveLimit 1 p of
        [sol] -> goldenText "test/golden/zebra-einstein.txt" (LRender.renderSolution p sol)
        _ -> expectationFailure "expected exactly one solution"

  it "rejects a category with the wrong number of values" $
    case LD.parseLogic (replaceLine "category color: red green blue" "category color: red green" zebraTiny) of
      Left (LogicFormat _) -> True `shouldBe` True
      Left _ -> expectationFailure "expected a LogicFormat error"
      Right _ -> expectationFailure "expected a parse failure"

  it "rejects more than 6 houses" $
    case LD.parseLogic ("houses: 7\ncategory name: Alice Bob Carol Dave Erin Frank Grace\nclues:\npos Alice 1\n") of
      Left (LogicFormat _) -> True `shouldBe` True
      Left _ -> expectationFailure "expected a LogicFormat error"
      Right _ -> expectationFailure "expected a parse failure"

  it "solves the example puzzle to the known unique solution" $
    case LD.parseLogic zebraTiny of
      Left e -> expectationFailure (show e)
      Right p -> case LD.solveLimit 1 p of
        [sol] -> V.toList (V.map V.toList (LD.unLogicSolution sol)) `shouldBe`
          [ ["Alice", "Bob", "Carol"]
          , ["tea", "coffee", "juice"]
          , ["green", "red", "blue"]
          ]
        _ -> expectationFailure "expected exactly one solution"

  it "reports a unique solution for the example" $
    case LD.parseLogic zebraTiny of
      Left e -> expectationFailure (show e)
      Right p -> length (LD.solveLimit 2 p) `shouldBe` 1

  it "finds all 3 solutions for the underconstrained puzzle" $
    case LD.parseLogic zebraUnderconstrained of
      Left e -> expectationFailure (show e)
      Right p -> length (LD.solveLimit 100 p) `shouldBe` 3

  it "solves through the shared typeclass interface" $
    case parsePuzzle zebraTiny :: Either SphinxError LD.LogicPuzzle of
      Left e -> expectationFailure (show e)
      Right p -> firstSolution p `shouldSatisfy` isJustOk

  it "renders the puzzle with question marks when unsolved" $
    case LD.parseLogic zebraTiny of
      Left e -> expectationFailure (show e)
      Right p -> do
        let rendered = LRender.renderPuzzle p
        rendered `shouldSatisfy` (not . null . lines)
        rendered `shouldSatisfy` any (== '?')

-- Replace the first occurrence of @old@ with @new@.
replaceLine :: String -> String -> String -> String
replaceLine old new input =
  let (headLines, tailLines) = break (== old) (lines input)
  in case tailLines of
       [] -> input
       (_ : after) -> unlines (headLines ++ [new] ++ after)

-- Replace each LF with CRLF.
crlf :: Char -> String
crlf '\n' = "\r\n"
crlf c = [c]

heartPuzzle :: String
heartPuzzle = unlines ["2 2", "7", "7", "5", "3", "1", "---", "2", "4", "5", "5", "5", "4", "2"]

goldenSpec :: Spec
goldenSpec = describe "Golden rendering" $ do
  it "renders the easy sudoku solution exactly" $
    case SP.parseSudoku easyPuzzle of
      Left e -> expectationFailure (show e)
      Right g -> case solveUpTo 1 g of
        (sol : _) -> goldenText "test/golden/sudoku-easy-solution.txt" (renderGrid sol)
        [] -> expectationFailure "no solution found"

  it "renders the logic example solution exactly" $
    case LD.parseLogic zebraTiny of
      Left e -> expectationFailure (show e)
      Right p -> case LD.solveLimit 1 p of
        (sol : _) -> goldenText "test/golden/zebra-einstein.txt" (LRender.renderSolution p sol)
        [] -> expectationFailure "no solution found"

  it "renders the nonogram heart solution exactly" $
    case parseNonogram heartPuzzle of
      Left e -> expectationFailure (show e)
      Right p -> case NS.solveUpTo 1 p of
        (sol : _) -> goldenText "test/golden/nonogram-heart.txt" (renderNonogram p sol)
        [] -> expectationFailure "no solution found"

-- Helpers ------------------------------------------------------------

expectedEasyGrid :: String
expectedEasyGrid = intercalate "\n"
  [ "+-------+-------+-------+"
  , "| 5 3 4 | 6 7 8 | 9 1 2 |"
  , "| 6 7 2 | 1 9 5 | 3 4 8 |"
  , "| 1 9 8 | 3 4 2 | 5 6 7 |"
  , "+-------+-------+-------+"
  , "| 8 5 9 | 7 6 1 | 4 2 3 |"
  , "| 4 2 6 | 8 5 3 | 7 9 1 |"
  , "| 7 1 3 | 9 2 4 | 8 5 6 |"
  , "+-------+-------+-------+"
  , "| 9 6 1 | 5 3 7 | 2 8 4 |"
  , "| 2 8 7 | 4 1 9 | 6 3 5 |"
  , "| 3 4 5 | 2 8 6 | 1 7 9 |"
  , "+-------+-------+-------+"
  ]

digitMatches :: Grid -> Step -> Bool
digitMatches sol st = case st of
  NakedSingle i d -> getCell sol i == d
  HiddenSingle i d _ -> getCell sol i == d
  Guess i d -> getCell sol i == d

wasEmpty :: Grid -> Step -> Bool
wasEmpty g st = case st of
  NakedSingle i _ -> getCell g i == 0
  HiddenSingle i _ _ -> getCell g i == 0
  Guess i _ -> getCell g i == 0

respectsGivens :: Grid -> Grid -> Bool
respectsGivens givens solved =
  all (\i -> getCell givens i == 0 || getCell solved i == getCell givens i) [0 .. 80]

headOrFail :: [a] -> a
headOrFail xs = case xs of
  (y : _) -> y
  [] -> error "headOrFail: empty list"

isJustOk :: Maybe a -> Bool
isJustOk (Just _) = True
isJustOk Nothing = False

-- The nonogram heart solution rendering, via the renderer.
renderNonogram :: Nonogram -> NT.Solution -> String
renderNonogram = NRender.renderSolution

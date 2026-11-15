-- | Sphinx test suite: unit tests for parsing and solving, property
-- tests for solver guarantees, and golden tests for the renderers.
module Main (main) where

import Data.Word (Word64)
import Test.QuickCheck
import Test.Hspec

import Golden (goldenText)

import Sphinx.Class (Puzzle(..), firstSolution, isUnique)
import Sphinx.Error (SphinxError(..))
import qualified Sphinx.Nonogram.Line as NLine
import Sphinx.Nonogram.Parse (parseNonogram)
import qualified Sphinx.Nonogram.Render as NRender
import qualified Sphinx.Nonogram.Solve as NS
import Sphinx.Nonogram.Types
import qualified Sphinx.Sudoku.Generate as Gen
import qualified Sphinx.Sudoku.Parse as SP
import Sphinx.Sudoku.Render (renderGrid)
import Sphinx.Sudoku.Solve (Step(..), solveUpTo, solveWithSteps)
import Sphinx.Sudoku.Types

-- The classic Wikipedia example puzzle and its known solution.
easyPuzzle :: String
easyPuzzle = "530070000600195000098000060800060003400803001700020006060000280000419005000080079"

hardPuzzle :: String
hardPuzzle = "800000000003600000075090000060005000000000000000400082000007980002400017001000000000040"  -- Arto Inkala

main :: IO ()
main = hspec $ do
  parseSpec
  sudokuSolveSpec
  sudokuPropertySpec
  generateSpec
  nonogramSpec
  classSpec
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
    SP.parseSudoku ("1........" ++ ".......1." ++ replicate 63 '.') `shouldBe` Left (SudokuConflict "kotak 1 (digit 1)")

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

  it "solves a known-hard puzzle" $
    case SP.parseSudoku hardPuzzle of
      Left e -> expectationFailure (show e)
      Right g -> do
        let solved = headOrFail (solveUpTo 1 g)
        isSolved solved `shouldBe` True
        respectsGivens g solved `shouldBe` True

  it "detects that a nearly empty board has multiple solutions" $
    case SP.parseSudoku (replicate 81 '.') of
      Left e -> expectationFailure (show e)
      Right g -> length (solveUpTo 2 g) `shouldBe` 2

  it "reports no solution when the puzzle is unsatisfiable" $ do
    -- Mutated from the classic easy puzzle: one given (position 1)
    -- changed to a digit that does not clash in its row, column or
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

  it "enumerates exactly the two fillings for 2+2 in length 6" $
    NLine.arrangements 6 [2, 2] `shouldBe`
      [ [True, True, False, True, True, False]
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
      Left _ -> pure ()  -- rejected at parse time also acceptable
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

  it "renders the nonogram heart solution exactly" $
    case parseNonogram heartPuzzle of
      Left e -> expectationFailure (show e)
      Right p -> case NS.solveUpTo 1 p of
        (sol : _) -> goldenText "test/golden/nonogram-heart.txt" (renderNonogram p sol)
        [] -> expectationFailure "no solution found"

-- Helpers ------------------------------------------------------------

expectedEasyGrid :: String
expectedEasyGrid = unlines
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
renderNonogram :: Nonogram -> Solution -> String
renderNonogram = NRender.renderSolution

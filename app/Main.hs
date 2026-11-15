-- | Sphinx command line interface.
--
-- All I/O lives here; the library is pure. Input puzzle files are
-- read once, parsed with the library, solved, and printed. The file
-- name @-@ reads from standard input.
module Main (main) where

import Control.Monad (when)
import Data.Word (Word64)
import Options.Applicative
import System.Exit (exitFailure)
import System.IO (hPutStrLn, stderr, withFile, IOMode(ReadMode), hFileSize)

import Sphinx.Class (Puzzle(..))
import Sphinx.Error (renderError)
import qualified Sphinx.Nonogram.Solve as Nonogram
import qualified Sphinx.Nonogram.Render as NRender
import qualified Sphinx.Sudoku.Generate as Gen
import Sphinx.Sudoku.Render (renderGrid, renderSteps)
import qualified Sphinx.Sudoku.Solve as Sudoku

-- Options -----------------------------------------------------------

data SudokuOpts = SudokuOpts
  { sudokuFile :: Maybe FilePath
  , sudokuCount :: Int
  , sudokuSteps :: Bool
  , sudokuGenerate :: Maybe String
  , sudokuSeed :: Maybe Word64
  }

data NonogramOpts = NonogramOpts
  { nonogramFile :: FilePath
  , nonogramSteps :: Bool
  }

data Command
  = CmdSudoku SudokuOpts
  | CmdNonogram NonogramOpts

sudokuOpts :: Parser SudokuOpts
sudokuOpts = SudokuOpts
  <$> optional (argument str (metavar "FILE" <> help "puzzle file, or '-' for stdin"))
  <*> option auto
        (long "count" <> metavar "N" <> value 1
        <> help "count up to N solutions (default 1); use 2 to check uniqueness")
  <*> switch (long "steps" <> help "print the deduction steps")
  <*> optional (option str (long "generate" <> metavar "DIFFICULTY"
        <> help "generate a puzzle instead of solving (easy|medium|hard)"))
  <*> optional (option auto (long "seed" <> metavar "N"
        <> help "PRNG seed for --generate"))

nonogramOpts :: Parser NonogramOpts
nonogramOpts = NonogramOpts
  <$> argument str (metavar "FILE" <> help "puzzle file, or '-' for stdin")
  <*> switch (long "steps" <> help "print search statistics")

commandParser :: Parser Command
commandParser = subparser
  ( command "sudoku"
      (info (CmdSudoku <$> sudokuOpts) (progDesc "Solve or generate a sudoku puzzle"))
  <> command "nonogram"
      (info (CmdNonogram <$> nonogramOpts) (progDesc "Solve a nonogram puzzle"))
  )

main :: IO ()
main = do
  cmd <- execParser opts
  case cmd of
    CmdSudoku o -> runSudoku o
    CmdNonogram o -> runNonogram o
  where
    opts = info (commandParser <**> helper <**> versionOption)
      ( fullDesc
      <> progDesc "Sphinx: constraint-based puzzle solver (sudoku, nonogram)"
      <> header "sphinx - puzzle solver" )
    versionOption = infoOption "sphinx 0.1.0" (long "version" <> help "show version")

-- Helpers ------------------------------------------------------------

die :: String -> IO a
die msg = hPutStrLn stderr ("sphinx: " ++ msg) >> exitFailure

-- | Refuse to read puzzle files larger than 1 MiB. Puzzles are tiny;
-- anything bigger is almost certainly a mistake.
maxPuzzleBytes :: Integer
maxPuzzleBytes = 1024 * 1024

readInput :: FilePath -> IO String
readInput "-" = getContents
readInput path = do
  size <- withFile path ReadMode hFileSize
  when (size > maxPuzzleBytes) $
    die ("puzzle file is too large (" ++ show size ++ " bytes); the limit is "
      ++ show maxPuzzleBytes ++ " bytes")
  readFile path

runSudoku :: SudokuOpts -> IO ()
runSudoku o
  | Just difficultyText <- sudokuGenerate o = generateCmd o difficultyText
  | otherwise = do
      file <- maybe (die "no puzzle file given (pass FILE, or use --generate DIFFICULTY)") pure (sudokuFile o)
      content <- readInput file
      case parsePuzzle content of
        Left err -> die (renderError err)
        Right grid -> do
          when (sudokuSteps o) $
            case Sudoku.solveWithSteps grid of
              Nothing -> die "no solution exists for this puzzle"
              Just (_, steps) -> putStrLn (renderSteps steps)
          let limit = max 1 (sudokuCount o)
              solutions = Sudoku.solveUpTo limit grid
          case solutions of
            [] -> die "no solution exists for this puzzle"
            (sol : _) -> putStrLn (renderGrid sol)
          when (sudokuCount o > 1) $
            putStrLn (countLine (length solutions) limit)

generateCmd :: SudokuOpts -> String -> IO ()
generateCmd o difficultyText =
  case Gen.parseDifficulty difficultyText of
    Nothing ->
      die ("unknown difficulty '" ++ difficultyText ++ "'; expected easy, medium or hard")
    Just difficulty -> do
      let seed = maybe 0x5deece66d id (sudokuSeed o)
          puzzle = Gen.generateSudoku difficulty seed
      putStrLn ("# difficulty: " ++ Gen.difficultyName difficulty ++ ", seed: " ++ show seed)
      putStrLn (renderGrid puzzle)

countLine :: Int -> Int -> String
countLine found cap
  | found >= cap = show cap ++ " or more solution(s); raise --count to see them all"
  | otherwise = show found ++ " solution(s)"

runNonogram :: NonogramOpts -> IO ()
runNonogram o = do
  content <- readInput (nonogramFile o)
  case parsePuzzle content of
    Left err -> die (renderError err)
    Right puzzle ->
      case Nonogram.solveWithStats puzzle of
        Nothing -> die "no solution exists for this puzzle"
        Just (solution, stats) -> do
          putStrLn (NRender.renderSolution puzzle solution)
          when (nonogramSteps o) $
            putStrLn ("search: " ++ show (Nonogram.guesses stats) ++ " guess(es), "
              ++ show (Nonogram.deadEnds stats) ++ " dead end(s) pruned")

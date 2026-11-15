-- | Error types for every failure mode Sphinx can report.
--
-- Every constructor carries enough data to build a friendly,
-- actionable message. Use 'renderError' to turn an error into text.
module Sphinx.Error
  ( SphinxError(..)
  , renderError
  ) where

-- | Unified error type for parsing and validating puzzles.
data SphinxError
  = -- | The cleaned input did not contain exactly 81 cells.
    SudokuWrongCellCount Int
  | -- | A character that is not a digit, '.', or '0' was found.
    SudokuInvalidChar Int Char
  | -- | Two equal non zero digits share a row, column, or box.
    SudokuConflict String
  | -- | The nonogram input is structurally broken (wrong sections,
    -- a clue line that is not a list of positive integers, or a
    -- clue list longer than its line).
    NonogramFormat String
  | -- | The nonogram shape is impossible (for example a row clue
    -- list that cannot fit the column count).
    NonogramInconsistent String
  | -- | The logic puzzle input is malformed (bad section, unknown
    -- clue token, unknown value, wrong house count, and so on).
    LogicFormat String
  deriving (Eq, Show)

-- | Render an error as a single human readable sentence.
renderError :: SphinxError -> String
renderError err = case err of
  SudokuWrongCellCount n ->
    "expected exactly 81 cells but found " ++ show n
      ++ ". Use '.' or '0' for empty cells; either one line of 81 characters"
      ++ " or 9 lines of 9 characters works."
  SudokuInvalidChar i c ->
    "invalid character " ++ show c ++ " at position " ++ show (i + 1)
      ++ ". Only digits 1-9, '.', and '0' are allowed."
  SudokuConflict unit ->
    "conflicting givens: duplicate digit in " ++ unit
      ++ ". Each row, column, and 3x3 box must contain each digit at most once."
  NonogramFormat what ->
    "malformed nonogram: " ++ what
  NonogramInconsistent what ->
    "inconsistent nonogram: " ++ what
  LogicFormat what ->
    "malformed logic puzzle: " ++ what

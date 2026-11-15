-- | A small Einstein/zebra style logic puzzle DSL and solver.
--
-- A logic puzzle (also known as a zebra puzzle) has a fixed number
-- of houses, a fixed set of named categories, and one assignment of
-- values per category. Clues constrain the assignments. The solver
-- finds every assignment that satisfies all clues.
--
-- File format (plain text, one entry per line, words separated by
-- single spaces):
--
-- > houses: 3
-- > category name: Alice Bob Carol
-- > category drink: tea coffee juice
-- > category color: red green blue
-- > clues:
-- > pos Alice 1
-- > eq tea green
-- > notsame Bob tea
-- > eq Carol juice
-- > leftof red juice
--
-- Supported clues (arguments are raw value words):
--
-- * @eq X Y@        X and Y are in the same house
-- * @pos X N@       value X is in house N (1-based)
-- * @nextto X Y@    X and Y are in adjacent houses
-- * @leftof X Y@    X is in a house somewhere to the left of Y
-- * @immleft X Y@   X is immediately to the left of Y
-- * @notsame X Y@   X and Y are in different houses
--
-- Values may be any non whitespace words (for example @Alice@,
-- @tea@, @red@). Every category must have exactly @houses@ values and
-- values may not repeat across categories. House count is between 2
-- and 6.
module Sphinx.Logic.DSL
  ( LogicPuzzle(..)
  , LogicCategory(..)
  , LogicSolution(..)
  , Clue(..)
  , SolveStats(..)
  , parseLogic
  , solveLimit
  , solveWithStats
  ) where

import Data.List (find, nub, permutations, sortBy, isSuffixOf)
import Data.Ord (comparing, Down(..))
import Data.Vector (Vector)
import qualified Data.Vector as V

import Sphinx.Error (SphinxError(..))

-- | A logic puzzle: house count, named categories and clues.
data LogicPuzzle = LogicPuzzle
  { houseCount :: Int
  , logicCategories :: Vector LogicCategory
  , logicClues :: [Clue]
  } deriving (Eq, Show)

-- | A named list of values. Values are unique across the whole puzzle.
data LogicCategory = LogicCategory
  { categoryName :: String
  , categoryValues :: [String]
  } deriving (Eq, Show)

-- | One clue. Arguments are raw value words from the input; each is
-- resolved to a (category, value index) pair during search.
data Clue
  = Eq String String
  | Pos String Int
  | NextTo String String
  | LeftOf String String
  | ImmediateLeft String String
  | NotSame String String
  deriving (Eq, Show)

-- | A solved logic puzzle: one string per (category, house). The
-- outer vector aligns with 'logicCategories'; each inner vector holds
-- the values for houses 1..N, in order.
newtype LogicSolution = LogicSolution { unLogicSolution :: V.Vector (V.Vector String) }
  deriving (Eq, Show)

-- | Statistics about one logic puzzle solve.
data SolveStats = SolveStats
  { logicGuesses :: Int    -- ^ category permutations tried during search
  , logicPruned :: Int     -- ^ branches pruned by violated clues
  } deriving (Eq, Show)

-- Value lookup ------------------------------------------------------

-- The (category index, value index) of every known value.
valueIndex :: LogicPuzzle -> [ (String, (Int, Int)) ]
valueIndex (LogicPuzzle _ cats _) =
  [ (v, (ci, vi))
  | (ci, cat) <- zip [0 ..] (V.toList cats)
  , (vi, v) <- zip [0 ..] (categoryValues cat)
  ]

lookupValue :: LogicPuzzle -> String -> Maybe (Int, Int)
lookupValue puzzle v = lookup v (valueIndex puzzle)

-- Parsing -------------------------------------------------------------

-- | Parse and validate a logic puzzle from its text form.
parseLogic :: String -> Either SphinxError LogicPuzzle
parseLogic input = do
  (n, rawCategories, clueLines) <- splitSections (cleanLines input)
  cats <- mapM buildCategory rawCategories
  validateShape n cats
  clues' <- mapM parseClue clueLines
  validateClues cats n clues'
  Right (LogicPuzzle n (V.fromList cats) clues')

cleanLines :: String -> [String]
cleanLines = filter (not . null) . map trim . lines . map crToLf
  where
    crToLf ch | ch == '\r' = '\n' | otherwise = ch
    trim = dropWhile isSpaceChar . reverse . dropWhile isSpaceChar . reverse
    isSpaceChar ch = ch == ' ' || ch == '\t'

splitSections :: [String] -> Either SphinxError (Int, [[String]], [[String]])
splitSections ls = do
  (housesLine, rest) <- case ls of
    (h : r) -> Right (h, r)
    [] -> Left (LogicFormat "expected 'houses: N' as the first line")
  n <- parseHousesLine housesLine
  let (catLines, afterCats) = span (/= "clues:") rest
      clueWords = map words (drop 1 afterCats)
  case afterCats of
    ("clues:" : _) -> do
      rawCats <- mapM parseCategoryLine catLines
      pure (n, rawCats, clueWords)
    _ -> Left (LogicFormat "expected a 'clues:' section")

parseHousesLine :: String -> Either SphinxError Int
parseHousesLine line =
  case words line of
    ["houses:", raw]
      | all isAsciiDigit raw && not (null raw) ->
          let parsed = read raw :: Int
          in if parsed >= 2 && parsed <= 6
               then Right parsed
               else Left (LogicFormat "houses must be between 2 and 6")
    _ -> Left (LogicFormat "expected 'houses: N' (for example 'houses: 3')")

isAsciiDigit :: Char -> Bool
isAsciiDigit ch = ch >= '0' && ch <= '9'

parseCategoryLine :: String -> Either SphinxError [String]
parseCategoryLine line =
  case words line of
    ("category" : name : ":" : values)
      | not (null values) && validWord name && all validWord values ->
          Right (name : values)
    ("category" : colonized : values)
      | let name = if ":" `isSuffixOf` colonized then init colonized else ""
      , not (null name) && not (null values) && validWord name && all validWord values ->
          Right (name : values)
    _ -> Left (LogicFormat ("expected 'category name: v1 v2 ...', got " ++ show line))
  where
    validWord s = not (null s) && s /= ":" && all (\ch -> ch /= ':') s

buildCategory :: [String] -> Either SphinxError LogicCategory
buildCategory (name : values) = Right (LogicCategory name values)
buildCategory _ = Left (LogicFormat "unreachable category shape")

validateShape :: Int -> [LogicCategory] -> Either SphinxError ()
validateShape n cats
  | null cats = Left (LogicFormat "expected at least one category line")
  | any (\c -> length (categoryValues c) /= n) cats =
      Left (LogicFormat ("every category must have exactly " ++ show n ++ " values"))
  | length allValues /= length (nub allValues) =
      Left (LogicFormat "every value may appear only once across all categories")
  | otherwise = Right ()
  where
    allValues = concatMap categoryValues cats

validateClues :: [LogicCategory] -> Int -> [Clue] -> Either SphinxError ()
validateClues cats houses clues = mapM_ check clues
  where
    check (Pos v n) = do
      _ <- needValue v
      if n >= 1 && n <= houses
        then Right ()
        else Left (LogicInconsistent ("house number out of range in clue: pos " ++ v ++ " " ++ show n))
    check (Eq a b) = checkPair a b
    check (NextTo a b) = checkPair a b
    check (LeftOf a b) = checkPair a b
    check (ImmediateLeft a b) = checkPair a b
    check (NotSame a b) = checkPair a b
    needValue v = case [ c | c <- cats, v `elem` categoryValues c ] of
      (c : _) -> Right c
      [] -> Left (LogicFormat ("unknown value " ++ show v ++ " in a clue"))
    checkPair a b = do
      ca <- needValue a
      cb <- needValue b
      if categoryName ca == categoryName cb
        then Left (LogicInconsistent ("a clue relates two values of the same category: " ++ a ++ " and " ++ b))
        else Right ()

parseClue :: [String] -> Either SphinxError Clue
parseClue ws = case ws of
  ["eq", a, b] -> Right (Eq a b)
  ["pos", a, raw]
    | all isAsciiDigit raw && not (null raw) -> Right (Pos a (read raw))
    | otherwise -> Left (LogicFormat ("pos clue needs a house number, got " ++ show raw))
  ["nextto", a, b] -> Right (NextTo a b)
  ["leftof", a, b] -> Right (LeftOf a b)
  ["immleft", a, b] -> Right (ImmediateLeft a b)
  ["notsame", a, b] -> Right (NotSame a b)
  _ -> Left (LogicFormat ("unknown clue or wrong arity: " ++ unwords ws))


-- Solving --------------------------------------------------------------

-- Internal assignment: one (length-n) vector per category, holding
-- 'Just permutation' for assigned categories and 'Nothing' otherwise.
-- A permutation maps house index -> value index.
type Partial = Vector (Maybe (Vector Int))

getHouse :: LogicPuzzle -> Partial -> String -> Maybe Int
getHouse puzzle partial value = do
  (catIdx, valIdx) <- lookupValue puzzle value
  case partial V.! catIdx of
    Nothing -> Nothing
    Just perm ->
      let n = V.length perm
          go i
            | i >= n = Nothing
            | perm V.! i == valIdx = Just i
            | otherwise = go (i + 1)
      in go 0

evalClue :: LogicPuzzle -> Partial -> Clue -> Maybe Bool
evalClue puzzle partial clue = case clue of
  Pos v n -> do
    h <- getHouse puzzle partial v
    Just (h == n - 1)
  Eq a b -> liftPair (==) a b
  NextTo a b -> liftPair (\x y -> abs (x - y) == 1) a b
  LeftOf a b -> liftPair (<) a b
  ImmediateLeft a b -> liftPair (\x y -> x + 1 == y) a b
  NotSame a b -> liftPair (/=) a b
  where
    liftPair f a b = do
      ha <- getHouse puzzle partial a
      hb <- getHouse puzzle partial b
      Just (f ha hb)

-- True when no assigned clue is violated (clues whose categories are
-- not yet assigned are 'Nothing' and pass).
branchConsistent :: LogicPuzzle -> Partial -> Bool
branchConsistent puzzle partial =
  all (/= Just False) (map (evalClue puzzle partial) (logicClues puzzle))

clueValues :: Clue -> [String]
clueValues clue = case clue of
  Eq a b -> [a, b]
  Pos v _ -> [v]
  NextTo a b -> [a, b]
  LeftOf a b -> [a, b]
  ImmediateLeft a b -> [a, b]
  NotSame a b -> [a, b]

-- Assign categories in descending order of clue degree, so clues
-- prune as early as possible.
searchOrder :: LogicPuzzle -> [Int]
searchOrder puzzle =
  let valueCats = valueIndex puzzle
      catOf v = maybe (-1) (fst . snd) (find ((== v) . fst) valueCats)
      mentions ci c = any (\v -> catOf v == ci) (clueValues c)
      degree ci = length [ c | c <- logicClues puzzle, mentions ci c ]
      nCats = V.length (logicCategories puzzle)
  in map fst (sortBy (comparing (Down . snd)) [ (i, degree i) | i <- [0 .. nCats - 1] ])

-- | Solve and report statistics about the search.
solveWithStats :: LogicPuzzle -> Maybe (LogicSolution, SolveStats)
solveWithStats puzzle = case searchWithStats puzzle of
  (first : _) -> Just first
  [] -> Nothing

searchWithStats :: LogicPuzzle -> [(LogicSolution, SolveStats)]
searchWithStats puzzle = go (searchOrder puzzle) (V.replicate nCats Nothing) (SolveStats 0 0)
  where
    nCats = V.length (logicCategories puzzle)
    n = houseCount puzzle
    perms = V.replicate nCats (V.fromList [ V.fromList p | p <- permutations [0 .. n - 1] ])
    go :: [Int] -> Partial -> SolveStats -> [(LogicSolution, SolveStats)]
    go [] assigned stats = [(toSolution puzzle assigned, stats)]
    go (i : is) assigned stats =
      let options =
            [ (perm, assigned')
            | perm <- V.toList (perms V.! i)
            , let assigned' = assigned V.// [(i, Just perm)]
            , branchConsistent puzzle assigned'
            ]
          pruned = V.length (perms V.! i) - length options
          stats' = SolveStats (logicGuesses stats + 1) (logicPruned stats + pruned)
      in [ (sol, finalStats)
         | (_, assigned') <- options
         , (sol, finalStats) <- go is assigned' stats'
         ]

toSolution :: LogicPuzzle -> Partial -> LogicSolution
toSolution puzzle partial =
  LogicSolution (V.fromList [ categorySolution cat perm | (cat, perm) <- zip catsList (V.toList partial) ])
  where
    catsList = V.toList (logicCategories puzzle)
    n = houseCount puzzle
    categorySolution _cat Nothing = V.replicate n "?"  -- unreachable for completed searches
    categorySolution cat (Just perm) =
      V.fromList [ categoryValues cat !! (perm V.! house) | house <- [0 .. n - 1] ]

-- | Solve a logic puzzle, returning up to @limit@ solutions.
solveLimit :: Int -> LogicPuzzle -> [LogicSolution]
solveLimit limit puzzle = take limit (map fst (searchWithStats puzzle))

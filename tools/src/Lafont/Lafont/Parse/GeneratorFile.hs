-- | Implements a parser for generator files.

module Lafont.Parse.GeneratorFile (
    -- Re-exports from internal.
    GFPError,
    -- Exports.
    GenFileSummary ( .. ),
    display,
    parseGenFileAsDict,
    parseGenFileAsAlphabet
) where

import           Lafont.Common
import           Lafont.Generators.Semantics
import           Lafont.Parse.Internal.GeneratorFile
import           Lafont.Parse.Semantics

-----------------------------------------------------------------------------------------
-- * Generator File Parsing Errors.

instance Display GenFileError where
    display MissingSemModel         = "Semantics model not provided."
    display (UnknownSemModel model) = "Unknown semantic model (" ++ model ++ ")."
    display (SemModelWOImpl model)  = display model ++ " not implemented."
    display InvalidGenName          = "Generator name started with invalid symbol."
    display (InvalidGenSem pos msg) = "Invalid semv at " ++ show pos ++ " (" ++ msg ++ ")."
    display (DuplicateGenName name) = "Duplicate generator name (" ++ name ++ ")."

-----------------------------------------------------------------------------------------
-- * Full Generator File Parsing.

-- | Lifts semantic value types to the return value. This is a cleaner alternative to the
-- type: Either (GenDict SemV1) (Either (GenDict SemV2), (Either SemV3 (Either ...)))).
--
-- In the future, this might also carry on parameters that describe the generator file.
data GenFileSummary = MonoidalGenSummary (GenDict ())
                    | DyadicTwoSummary (GenDict TwoQubitDyadic)
                    | DyadicThreeSummary (GenDict ThreeQubitDyadic)
                    deriving (Eq,Show)

-- | Consumes all lines of a generator file (lines). If the lines are valid, then returns
-- a dictionary of all generators and their semantics, wrapped by their semantic model.
-- Otherwise, returns a parsing exception.
parseGenFileAsDict :: [String] -> Int -> Either (Int, GFPError) GenFileSummary
parseGenFileAsDict lines num =
    case parseSemanticModel lines 0 of
        Left err                 -> Left err
        Right (sem, semLn, gens) -> let nextLn = semLn + 1 in case sem of
            MonoidalSem -> case parseGenDict parseMonoidalSem gens nextLn of
                Left err   -> Left err
                Right dict -> Right (MonoidalGenSummary dict)
            DyadicTwoSem -> case parseGenDict interpret2QubitCliffordDTofGate gens nextLn of
                Left err   -> Left err
                Right dict -> Right (DyadicTwoSummary dict)
            DyadicThreeSem -> case parseGenDict interpret3QubitCliffordDTofGate gens nextLn of
                Left err   -> Left err
                Right dict -> Right (DyadicThreeSummary dict)
            _ -> Left (semLn, Right (SemModelWOImpl sem))

-- | A GenFileSummary carries the type data of the underlying semantic model. This
-- function allows all semantic data to be stripped away, returning instead a list of
-- generator symbols. Consumes all lines of a generator file (lines). If the lines are
-- valid, then returns a list of all generator symbols. Otherwise, returns a parsing
-- exception.
parseGenFileAsAlphabet :: [String] -> Int -> Either (Int, GFPError) [String]
parseGenFileAsAlphabet lines num = case parseGenFileAsDict lines num of
    Left err                        -> Left err
    Right (MonoidalGenSummary dict) -> Right (toAlphabet dict)

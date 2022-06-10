-- | Implements a parser for generator files.

module DyadicRewrite.Parse.RelationFile where

import DyadicRewrite.Common
import DyadicRewrite.Rewrite.Rules
import DyadicRewrite.Rewrite.Lookup
import DyadicRewrite.Parse.Common
import DyadicRewrite.Parse.MonWords

-----------------------------------------------------------------------------------------
-- * Generator File Parsing Errors.

-- | Errors unique to generator file parsing.
data RelFileError = InvalidRuleName
                  | RuleMissingLHS 
                  | InvalidRuleType Int
                  | RuleMissingRHS
                  | UnknownGenName String
                  | DuplicateRuleName String
                  deriving (Eq)

instance Show RelFileError where
    show InvalidRuleName          = "Rule name started with invalid symbol."
    show RuleMissingLHS           = "Rule missing left-hand side."
    show (InvalidRuleType pos)    = "Invalid rule type at pos " ++ (show pos) ++ "."
    show RuleMissingRHS           = "Rule missing right-hand side."
    show (UnknownGenName name)    = "Unknown generator name (" ++ name ++ ")."
    show (DuplicateRuleName name) = "Duplicate rule name (" ++ name ++ ")."

-- | Errors returned during generator file parsing.
type RFPError = Either ParserError RelFileError

-----------------------------------------------------------------------------------------
-- * Functions to Validate Monoidal Words.

-- | Consumes a list of generator names (gens) and a monoidal word (word). Returns the
-- first symbol in monoidal word with either a non-zero number of parameters or a name
-- not in gens. If no such symbol exists, then nothing is returned.
findUnknownGenInMonWord :: [String] -> MonWord -> Maybe Symbol
findUnknownGenInMonWord gens []          = Nothing
findUnknownGenInMonWord gens (symb:word) = if symbolIsValid
                                           then findUnknownGenInMonWord gens word
                                           else Just symb
    where symbolIsValid = ((args symb) == []) && ((name symb) `elem` gens)

-- | Consumes a list of generator names (gens) and a rule. Returns the first symbol (on
-- either the lhs, or rhs, with priority for the lhs) which violates the checks of
-- findUnknownGenInMonWord. If no such symbol exists, then nothing is returned.
findUnknownGenInRule :: [String] -> RewriteRule -> Maybe Symbol
findUnknownGenInRule gens rule =
    case (findUnknownGenInMonWord gens (lhs rule)) of
        Just gen -> Just gen
        Nothing  -> (findUnknownGenInMonWord gens (rhs rule))

-----------------------------------------------------------------------------------------
-- * Line Parsing Helper Methods.

-- | Helper function to propogation relation file errors from unnamed rewrite rule
-- parsing to named rewrite rule parsing. For example, if an error occurs at index 5 of
-- substr, and if substr appears at index 7 of str, then the error is updated to display
-- index 12.
propRelErr :: String -> String -> RFPError -> RFPError
propRelErr str substr err =
    case err of
        Left (UnexpectedSymbol pos) -> Left (UnexpectedSymbol (update pos))
        Right (InvalidRuleType pos)  -> Right (InvalidRuleType (update pos))
        otherwise                   -> err
    where update pos = relToAbsErrPos str substr pos

-----------------------------------------------------------------------------------------
-- * Line Parsing Methods.

-- | Consumes a string that represents a rewrite rule (str). Attempts to parse a rule of
-- the form <MON_WORD> <OP> <MON_WORD> where <OP> is one of = or →. Requires that str
-- does not have leading whitespace. Error messages are given with respect to indices in
-- str.
parseRule :: String -> Either RFPError RewriteRule
parseRule str =
    case (parseMonWord str) of
        Just (lhs, opStr) -> case (parseFromSeps ["→", "="] opStr) of
            Just (op, rhsStr) -> case (parseMonWord (snd (trimSpacing rhsStr))) of
                Just (rhs, post) -> let lval = Left (UnexpectedSymbol (getErrPos str post))
                                        rval = RewriteRule lhs rhs (op == "=") False
                                    in branchOnSpacing post lval rval
                Nothing -> Left (Right RuleMissingRHS)
            Nothing -> Left (Right (InvalidRuleType (getErrPos str opStr)))
        Nothing -> Left (Right RuleMissingLHS)

-- | Consumes a single line of a relation file (str). Attempts to parse a named rewrite
-- rule from str. If parsing is successful, then (id, rule) is returned where rule is a
-- rewrite rule and id is its name. Otherwise, an error type is returned.
parseRuleDefn :: String -> Either RFPError (String, RewriteRule)
parseRuleDefn str =
    case (parseId (snd (trimSpacing str))) of
        Just (id, ruleStr) -> let (isTrimmed, trimmed) = trimSpacing ruleStr
                             in if isTrimmed
                                then case (parseRule trimmed) of
                                         Left err   -> Left (propRelErr str trimmed err)
                                         Right rule -> Right (id, rule)
                                else Left (Left (UnexpectedSymbol (getErrPos str ruleStr)))
        Nothing -> Left (Right InvalidRuleName)

-- | Consumes a partial map of rewrite rules (dict), a list of generator names (gens),
-- and a single line of a generator file (str). Attemps to call (parseRuleDefn str) and
-- then add the result to dict. If parseGenerator fails, then the error is forwarded. If
-- a rewrite rule contains an unknown generator, then an UnknownGeneratorName error is
-- returned. If the rewrite rule's name is a duplicate, then a DuplicateRuleName error is
-- returned. If no errors occur, then the ID and rewrite rule returned by parseGenerator
-- are added to dict. The resulting dict is returned.
updateRules :: RuleDict -> [String] -> String -> Either RFPError RuleDict
updateRules dict gens str =
    case (parseRuleDefn str) of
        Left err        -> Left err
        Right (id, rule) -> case (findUnknownGenInRule gens rule) of
            Just gen -> Left (Right (UnknownGenName (show gen)))
            Nothing  -> if (dict `hasRule` id)
                        then Left (Right (DuplicateRuleName id))
                        else Right (dict `addRule` (id, rule))

-----------------------------------------------------------------------------------------
-- * File Parsing Methods.

-- | Consumes all lines of a relation file (lines), a list of generator names (gens), and
-- the current line number (num). If the lines are valid, then returns a dictionary of
-- all rewrite rules. Otherwise, returns a parsing exception.
parseRelFile :: [String] -> [String] -> Int -> Either (Int, RFPError) RuleDict
parseRelFile _    []           _   = Right empty
parseRelFile gens (line:lines) num =
    case (parseRelFile gens lines (num + 1)) of
        Left  err  -> Left err
        Right dict -> case (cleanLine line) of
            ""   -> Right dict
            text -> case (updateRules dict gens text) of
                Left err   -> Left (num, (propRelErr line text err))
                Right dict -> Right dict

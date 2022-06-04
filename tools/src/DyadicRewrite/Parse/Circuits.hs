-- | Parsing functions for circuits.

module DyadicRewrite.Parse.Circuits where

import DyadicRewrite.Common
import DyadicRewrite.Parse.Common

-----------------------------------------------------------------------------------------
-- * Utilities to parse circuit parameters..

-- | Helper function to parse: [ <NAT> ].
parseParam :: String -> Maybe (Int, String)
parseParam []        = Nothing
parseParam ('[':str) =
    case (parseNat str) of
        Just (n, post) -> case (parseFromSeps ["]"] post) of
            Just (_, post') -> Just (n, post')
            Nothing         -> Nothing
        Nothing -> Nothing
parseParam _ = Nothing

-- | Consumes a string (str). If there exists a string pre = [i1][i2][i3]...[in] such
-- that i1, i2, i3, ..., in are natural numbers, str = pre + post, and pre is the maximal
-- such prefix, then ([i1,i2,i3,...,in], post) is returned. Otherwise, nothing is
-- returned.
parseParams :: String -> ([Int], String)
parseParams str =
    case (parseParam str) of
        Just (param, post) -> let (params, post') = (parseParams post)
                              in (param:params, post')
        Nothing -> ([], str)

-----------------------------------------------------------------------------------------
-- * Utilities to parse circuit gates.

-- | Consumes a string (str). If there exists a string pre of the form <ID><PARAMS> that
-- str = pre + post, then returns (Gate <ID> <PARAM>, post) where pre is the maximal such
-- prefix. Otherwise, nothing is returned.
parseGate :: String -> Maybe (Gate, String)
parseGate str = 
    case (parseId str) of
        Just (id, post) -> let (params, post') = (parseParams post)
                           in Just ((Gate id params), post')
        Nothing -> Nothing
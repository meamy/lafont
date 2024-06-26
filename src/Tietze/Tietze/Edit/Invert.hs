-- | This module provides tools to invert a rewrite rule through a combination
-- of elimination and introduction rules.

module Tietze.Edit.Invert
  ( EIRewrite (..)
  , EIView
  , InversionProof (..)
  , ViewQueryRes (..)
  , addEIRule
  , createView
  , deriveElim
  , deriveIntro
  , invertRule
  , findEIRule
  , getInvProof
  , hasLeftInvs
  , viewByQuery
  ) where
 
-----------------------------------------------------------------------------------------
-- * Import Section.

import qualified Data.Map as Map
import qualified Data.Set as Set

import Tietze.Common
  ( Display (..)
  , MonWord
  , Symbol
  )
import Tietze.Maybe (branchJust)
import Tietze.Edit.EIRules
  ( EIDict
  , EIQueryType
  , getInv
  , hasLeftInv
  , isAppliedOnLeft
  , queryEIRule
  )
import Tietze.Edit.Internal.EIRules
  ( EIRule (..)
  , IsLeftInv
  )
import Tietze.Rewrite.Common (RuleDir(..))
import Tietze.Rewrite.Rules
  ( Rewrite (..)
  , RewriteRule (..)
  , formatRewrite
  )

-----------------------------------------------------------------------------------------
-- * Data-Types to Specify a Selection of EIRules

-- | A single symbol might have multiple elimination (resp. introduction) rules. Even if
-- all elimination (resp. introduction) rules are equivalent up to isomorphism (e.g., the
-- rules encode group inverses), this choice of syntactic representation still impacts
-- the structure of a derivational proof. An EIView solves this problem by selecting a
-- single elimination (resp. introduction) rule for each symbol. In addition, each EIView
-- enforces that all inverses appear strictly on either the left or right.
data EIView = EIView IsLeftInv (Map.Map Symbol EIRule) deriving (Show, Eq)

-- | Initializes a new EIView in which no symbol has elimination (resp. introduction)
-- rule. The addRule method is used to assign rules to symbols.
createView :: IsLeftInv -> EIView
createView usingLeftInv = EIView usingLeftInv Map.empty

-- | Consumes an EIView, and a pair consisting of a symbol and an EIRule. Returns a new
-- view in which the given symbol is associated with the given EIRule, and all other
-- mappings remain unchanged.
addEIRule :: EIView -> (Symbol, EIRule) -> Maybe EIView
addEIRule (EIView usingLeftInv map) (sym, rule) =
    if usingLeftInv == hasLeftInv rule
    then Just $ EIView usingLeftInv $ Map.insert sym rule map
    else Nothing

-- | Consumes an EIView and a symbol. If the symbol is associated with an EIRule, then
-- returns the EIRule. Otherwise, nothing is returned.
findEIRule :: EIView -> Symbol -> Maybe EIRule
findEIRule (EIView _ map) sym = Map.lookup sym map

-- | Returns true if an EIVIew contains rules using left inverses.
hasLeftInvs :: EIView -> IsLeftInv
hasLeftInvs (EIView usingLeftInv _) = usingLeftInv

-----------------------------------------------------------------------------------------
-- * View Generation (by query policy).

-- | Encodes an EI view of symbol queries, or the first symbol whose query failed.
data ViewQueryRes = QueryFailure Symbol
                  | QuerySuccess EIView
                  deriving (Show, Eq)

-- | Implementation details for viewByQuery (fold function).
viewByQueryImpl :: EIDict -> EIQueryType -> Symbol -> ViewQueryRes -> ViewQueryRes
viewByQueryImpl _    _  _   rv@(QueryFailure _) = rv
viewByQueryImpl dict ty sym (QuerySuccess view) =
    case queryEIRule dict sym ty of
        Nothing   -> QueryFailure sym
        Just rule -> case addEIRule view (sym, rule) of
            Nothing    -> QueryFailure sym
            Just view' -> QuerySuccess view'

-- | Consumes a set of symbols, a query type, and an EI dictionary. If each symbol can be
-- queried successfully in the EI dictionary, then returns a EI view with the
-- corresponding query results. Otherwise, the first symbol is returned whose query could
-- not be satisfied.
viewByQuery :: Set.Set Symbol -> EIQueryType -> EIDict -> ViewQueryRes
viewByQuery symset ty dict = Set.foldr f v symset
    where v = QuerySuccess $ createView $ isAppliedOnLeft dict
          f = viewByQueryImpl dict ty

-----------------------------------------------------------------------------------------
-- * Functions to Invert Rewrite Rules.

-- | Implementation details for invertStr. Excepts that the word is reversed, so that
-- the resulting string appears in a contravariant order.
invertStrImpl :: EIView -> MonWord -> Maybe MonWord
invertStrImpl _     []        = Just []
invertStrImpl view (sym:word) =
    branchJust (findEIRule view sym) $ \rule ->
        branchJust (invertStrImpl view word) $ \dword ->
            Just $ getInv rule ++ dword

-- | Implements invertRule for a single side of a RewriteRule. Note that the invert of
-- the lhs and rhs only differ in the choice of view.
invertStr :: EIView -> MonWord -> Maybe MonWord
invertStr view word = invertStrImpl view $ reverse word

-- | Consumes an EIView for elimination rules, an EIView for introduction rules, and an
-- arbitrary rewrite rule. If a symbol appears in the rewrite rule which does not appear
-- in the corresponding EIView (lhs is introduced, rhs is eliminated), then nothing is
-- returned. Otherwise, returns inverted relation.
invertRule :: EIView -> EIView -> RewriteRule -> Maybe (MonWord, MonWord)
invertRule eview iview rule =
    branchJust (invertStr eview $ rhs rule) $ \lstr ->
        branchJust (invertStr iview $ lhs rule) $ \rstr -> Just (lstr, rstr)

-----------------------------------------------------------------------------------------
-- * Type to Encode EIRule Derivations.

-- | A variation of the Rewrite type for EIRules.
data EIRewrite = EIRewrite Int EIRule deriving (Show, Eq)

instance Display EIRewrite where
    display (EIRewrite pos (EIRule name _ dir _ isDerived)) = str
        where str = formatRewrite name isDerived dir pos

-----------------------------------------------------------------------------------------
-- * Functions to Derive Inverse Rewrite Rules.

-- | Helper method to implement derivElim and deriveIntro. The additional function from
-- EIRule to integer is used to track the current index in the derivation. Specifically,
-- for each EIRule in the derivation, the function should return the number of positions
-- by which the rule moves the current index.
seqToDer :: (EIRule -> Int) -> EIView -> Int -> MonWord -> Maybe (Int, [EIRewrite])
seqToDer _     _    n []         = Just (n, [])
seqToDer delta view n (sym:word) =
    branchJust (findEIRule view sym) $ \rule ->
        let n' = n + delta rule
        in branchJust (seqToDer delta view n' word) $ \(end, deriv) ->
            Just (end, EIRewrite n rule:deriv)

-- | This function expands elimination rules from symbols to words. The function takes
-- as input a view of in-scope elimination rules, the current index, and the word to
-- eliminate at this index. Whether inverses appear on the left or right is inferred from
-- the view. If the elimination is possible, then returns a sequence of eliminations,
-- together with the new index after the sequence of eliminations. Otherwise, nothing is
-- returned. Note that derivation only fails if a elim rule is missing.
deriveElim :: EIView -> Int -> MonWord -> Maybe (Int, [EIRewrite])
deriveElim view n word = seqToDer delta view n seq
    where linvs = hasLeftInvs view
          seq    = if linvs then word else reverse word
          delta  = if linvs then negate . length . getInv else const (- 1)

-- | This function expands introduction rules from symbols to words. The function takes
-- as input a view of in-scope introduction rules, the current index, and the word to
-- introduce at this index. Whether inverses appear on the left or right is inferred from
-- the view. If the introduction is possible, then returns a sequence of introductions,
-- together with the new index after the sequence of introduction. Otherwise, nothing is
-- returned. Note that derivation only fails if an intro rule is missing.
deriveIntro :: EIView -> Int -> MonWord -> Maybe (Int, [EIRewrite])
deriveIntro view n word = seqToDer delta view n seq
    where linvs = hasLeftInvs view
          seq    = if linvs then reverse word else word
          delta  = if linvs then length . getInv else const 1

-- | Summarizes a derivation proof to invert a relation. The rewrite rule envoked during
-- the swapStep is the relation under inversion. The proof is as follows:
--      <invLhs>
--      <introStep[0]>
--      <introStep[1]>
--      ...
--      <introStep[n]>
--      <swapStep>
--      <elimStep[0]>
--      <elimStep[1]>
--      ...
--      <elimStep[m]>
data InversionProof = InversionProof { invLhs    :: MonWord
                                     , invRhs    :: MonWord
                                     , introStep :: [EIRewrite]
                                     , swapStep  :: Rewrite
                                     , elimStep  :: [EIRewrite]
                                     } deriving (Show, Eq)

-- | Implementation details for getInvProof. Explicitly consumes the inverted left-hand
-- side and right-hand side.
getInvProofImpl :: EIView -> EIView -> RewriteRule -> MonWord -> MonWord
                          -> Maybe InversionProof
getInvProofImpl eview iview rule linv rinv =
    branchJust (deriveIntro iview pos1 $ lhs rule) $ \(_, isteps) ->
        branchJust (deriveElim eview pos3 $ rhs rule) $ \(_, esteps) ->
            Just $ InversionProof linv rinv isteps swap esteps
    where rlen = length $ rhs rule 
          swap = Rewrite rule pos2 L2R
          pos1 = if hasLeftInvs eview then length linv else 0
          pos2 = if hasLeftInvs eview then pos1 else length rinv
          pos3 = if hasLeftInvs eview then pos2 - 1 else pos2 + rlen - 1

-- | Takes as input a view of elimination rules (eview), a view of introduction rules
-- (iview), and a rewrite rule. Attempts to invert the rule, according to eview and
-- iview. The type of the new rule will be determined by (invertRule eview iview rule).
-- The rule will be defined via a derivational proof.
getInvProof :: EIView -> EIView -> RewriteRule -> Maybe InversionProof
getInvProof eview iview rule =
    if hasLeftInvs eview == hasLeftInvs iview
    then Nothing
    else branchJust (invertRule eview iview rule) $ \(linv, rinv) ->
        getInvProofImpl eview iview rule linv rinv

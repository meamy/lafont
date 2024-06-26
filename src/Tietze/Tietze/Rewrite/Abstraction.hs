-- | This module provides data types and functions to work with derivations before all
-- derived relation applications have been resolved.

module Tietze.Rewrite.Abstraction
  ( Apply (..)
  , UnmetDep (..)
  , DepGraph
  , AbsDerivation (..)
  , DerivationMap
  , AbsRewrite
  , DepCycle
  , addDRules
  , registerDerivations
  , addDerivationToGraph
  , addDerivationsToGraph
  , derivationToGraph
  , detectDerivationError
  , getDerivation
  , makeDerivationMap
  , identifyEquationalRules
  , unwrapDepGraph
) where
 
-----------------------------------------------------------------------------------------
-- * Import Section.

import qualified Data.Map as Map

import Data.Maybe (fromMaybe)
import Tietze.Either (branchRight)
import Tietze.Graph
  ( Digraph
  , GraphWalk
  , addVertex
  , findCycle
  , nullgraph
  )
import Tietze.Maybe (maybeApply)
import Tietze.Rewrite.Lookup (RuleDict)
import Tietze.Rewrite.Internal.Abstraction
  ( AbsRewrite
  , Apply (..)
  , Dependency
  , DepGraph (..)
  , UnmetDep (..)
  , addDepsToGraph
  )
import Tietze.Rewrite.Rules
  ( Rewrite (..)
  , equational
  )
import Tietze.Rewrite.Summary
  ( DerivationSummary (..)
  , EqMap
  , addDRule
  , containsRule
  , defaultEqMap
  , isEquationalDerivation
  , propName
  , setAsEquational
  , setAsOrientated
  )

-----------------------------------------------------------------------------------------
-- * Derivations with Apply Types.

-- | Provides an abstract view of a derivational proof. In an abstract proof, each step
-- is either a rewrite or the application of a derived relation. In other words, the
-- proof consists of abstract rewrites.
data AbsDerivation = AbsDerivation DerivationSummary [AbsRewrite] deriving (Show, Eq)

-- | Helper method to get summary from abstract derivation.
_getSummary :: AbsDerivation -> DerivationSummary
_getSummary (AbsDerivation summary _) = summary

-----------------------------------------------------------------------------------------
-- * Derivation to Graph Conversion

-- | Consumes a list of derivations (list). Returns a dependency graph with a vertex for
-- each derivation in list. A special vertex is added for unnamed derivations ("0").
registerDerivations :: [AbsDerivation] -> DepGraph
registerDerivations []           = DepGraph $ addVertex nullgraph "0"
registerDerivations (deriv:list) =
    case propName $ meta $ _getSummary deriv of
        Just name -> DepGraph $ addVertex g name
        Nothing   -> DepGraph g
    where (DepGraph g) = registerDerivations list

-- | Consumes a derivation and a graph. If the derivation is named, then returns the
-- result of addDepsToGraph using the name and rewrites of the derivation. Otherwise,
-- returns the results of addDepsToGraph using the name "0" and the rewrites of the
-- derivation.
addDerivationToGraph :: AbsDerivation -> DepGraph -> Either UnmetDep DepGraph
addDerivationToGraph (AbsDerivation summary rewrites) g =
    case propName $ meta summary of
        Just src -> addDepsToGraph src rewrites g
        Nothing  -> addDepsToGraph "0" rewrites g

-- | Consumes a list of derivations (derivations) and a graph (g). If there exists a
-- derivation (d) in rewrites such that (addDerivationToGraph d g) returns an error, then
-- the first such error is returns. Otherwise, is equivalent to folding derivations using
-- addDerivationToGraph.
addDerivationsToGraph :: [AbsDerivation] -> DepGraph -> Either UnmetDep DepGraph
addDerivationsToGraph []                       g = Right g
addDerivationsToGraph (derivation:derivations) g =
    branchRight (addDerivationToGraph derivation g) (addDerivationsToGraph derivations)

-- | Returns the digraph underlying a DepGraph.
unwrapDepGraph :: DepGraph -> Digraph Dependency
unwrapDepGraph (DepGraph g) = g

-----------------------------------------------------------------------------------------
-- * Cycle Detection

-- | A sequence of derivations that depend on one-another.
type DepCycle = GraphWalk Dependency

-- | Consumes a list of derivations. If the list contains an unmet dependency (i.e., one
-- derivation calls an unknown derivation), then just the name of the dependency is
-- returned. Otherwise, the corresponding dependency graph is returned.
derivationToGraph :: [AbsDerivation] -> Either UnmetDep DepGraph
derivationToGraph derivations = addDerivationsToGraph derivations g
    where g = registerDerivations derivations

-- | Consumes a list of derivations. If the list contains an unmet dependency (i.e., one
-- derivation calls an unknown derivation), then just the name of the dependency is
-- returned. If the list contains a dependency cycle, then just the cycle is returned.
-- Otherwise, nothing is returned.
detectDerivationError :: [AbsDerivation] -> Maybe (Either UnmetDep DepCycle)
detectDerivationError derivations =
    case derivationToGraph derivations of
        Left unmet         -> Just $ Left unmet
        Right (DepGraph g) -> maybeApply (findCycle g) Right

-----------------------------------------------------------------------------------------
-- * Utilities to Look up Derivations by Name.

-- | A mapping from derivation names to their information.
newtype DerivationMap = DerivationMap (Map.Map String AbsDerivation)

-- | Attemtps to find a derivation of a given name.
getDerivation :: DerivationMap -> String -> Maybe AbsDerivation
getDerivation (DerivationMap map) name = name `Map.lookup` map

-- | Consumes  list of abstract derivations. Returns a derivation map containing an entry
-- for each named derivation in the list.
makeDerivationMap :: [AbsDerivation] -> DerivationMap
makeDerivationMap []                       = DerivationMap Map.empty
makeDerivationMap (derivation:derivations) =
    case propName $ meta $ _getSummary derivation of
        Just name -> DerivationMap $ Map.insert name derivation dict
        Nothing   -> DerivationMap dict
    where (DerivationMap dict) = makeDerivationMap derivations

-----------------------------------------------------------------------------------------
-- * Equationality of Abstract Relations

-- | Updates emap according to isEqn.
ierBody :: DerivationMap -> String -> [AbsRewrite] -> EqMap -> Bool -> EqMap
ierBody dmap name rewrites emap True  = ierSplit dmap name rewrites emap
ierBody _    name _        emap False = setAsOrientated emap name

-- | Analyzes the steps of a derivation to assert equationality.
ierSplit :: DerivationMap -> String -> [AbsRewrite] -> EqMap -> EqMap
ierSplit _    name []                emap = setAsEquational emap name
ierSplit dmap name (Left r:rewrites) emap = ierBody dmap name rewrites emap isEqn
    where (Rewrite rule _ _) = r
          isEqn = equational rule
ierSplit dmap name (Right r:rewrites) emap = ierBody dmap name rewrites emap' isEqn
    where (Apply rule _ _) = r
          Just appliedDerivtion = dmap `getDerivation` rule
          emap' = ierFold dmap rule appliedDerivtion emap
          -- The following line should never return maybe. The default False is safe.
          isEqn = fromMaybe False $ emap' `isEquationalDerivation` rule

-- | Fold implementation for identifyEquationalRules.
ierFold :: DerivationMap -> String -> AbsDerivation -> EqMap -> EqMap
ierFold dmap name (AbsDerivation _ rewrites) emap
    | emap `containsRule` name = emap
    | otherwise                = ierSplit dmap name rewrites emap

-- | Consumes a list of abstract deriviations. It is assumed that the abstract
-- derivations have passed a detectDerivationError test (e.g., all dependencies are met
-- and the graph is acyclic). Returns an equational map for the derivations.
identifyEquationalRules :: DerivationMap -> EqMap
identifyEquationalRules (DerivationMap dmap) = Map.foldrWithKey f defaultEqMap dmap
    where f = ierFold $ DerivationMap dmap

-----------------------------------------------------------------------------------------
-- * Interpreting Abstract Derivations as Rules

-- | Consumes a rule dictionary and a list of absolute derivations. Records the summaries
-- of all named derivations in the rule dictionary, and returns the resulting dictionary.
addDRules :: RuleDict -> [AbsDerivation] -> RuleDict
addDRules rules derivs = Prelude.foldr f rules sums
    where dmap  = makeDerivationMap derivs
          emap  = identifyEquationalRules dmap
          sums  = Prelude.map _getSummary derivs
          f s m = addDRule m emap s

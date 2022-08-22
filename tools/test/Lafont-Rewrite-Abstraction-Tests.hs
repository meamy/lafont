module Main where

import Test.Framework
import Test.Framework.Providers.HUnit
import Test.HUnit
import Lafont.Common
import Lafont.Rewrite.Abstraction
import Lafont.Rewrite.Common
import Lafont.Rewrite.Rules
import Lafont.Rewrite.Summary

-----------------------------------------------------------------------------------------
-- Declares derivations for tests.

rel1 = "rel1"
rel2 = "rel2"
rel3 = "rel3"
rel4 = "rel4"
rel5 = "rel5"
rel6 = "rel6"
rel7 = "rel7"
rel8 = "rel8"
relx = "relx"

summary1 = DerivationSummary (RewritePreamble (Just rel1)) [] []
summary2 = DerivationSummary (RewritePreamble (Just rel2)) [] []
summary3 = DerivationSummary (RewritePreamble (Just rel3)) [] []
summary4 = DerivationSummary (RewritePreamble (Just rel4)) [] []
summary5 = DerivationSummary (RewritePreamble (Just rel5)) [] []
summary6 = DerivationSummary (RewritePreamble (Just rel6)) [] []
summary7 = DerivationSummary (RewritePreamble (Just rel7)) [] []
summary8 = DerivationSummary (RewritePreamble (Just rel8)) [] []
nameless = DerivationSummary (RewritePreamble Nothing) [] []

symb1 = Symbol "S" []
symb2 = Symbol "T" []
symb3 = Symbol "U" []

word1 = [symb1, symb1, symb1]
word2 = [symb2, symb2, symb2]
word3 = [symb3, symb3, symb3]

rule1 = RewriteRule word1 word2 True Nothing
rule2 = RewriteRule word1 word3 True Nothing
rule3 = RewriteRule word2 word3 True Nothing

rw1 = Rewrite rule1 0 L2R
rw2 = Rewrite rule2 0 L2R
rw3 = Rewrite rule3 0 L2R

rewrites1 :: [AbsRewrite]
rewrites1 = [Left rw1, Left rw1, Left rw1]

rewrites2 :: [AbsRewrite]
rewrites2 = [Left rw2, Left rw2, Left rw2]

rewrites3 :: [AbsRewrite]
rewrites3 = [Left rw3, Left rw3, Left rw3]

derivation1 = AbsDerivation summary1 rewrites1
derivation2 = AbsDerivation summary2 rewrites2
derivation3 = AbsDerivation summary3 rewrites3

-----------------------------------------------------------------------------------------
-- makeDerivationMap

map0 = makeDerivationMap []
map1 = makeDerivationMap [derivation1]
map2 = makeDerivationMap [derivation1, derivation2]
map3 = makeDerivationMap [derivation1, derivation2, derivation3]

test1 = TestCase (assertEqual "makeDerivationMap after 0 inserts (1/4)."
                              Nothing
                              (getDerivation map0 rel1))

test2 = TestCase (assertEqual "makeDerivationMap after 0 inserts (2/4)."
                              Nothing
                              (getDerivation map0 rel2))

test3 = TestCase (assertEqual "makeDerivationMap after 0 inserts (3/4)."
                              Nothing
                              (getDerivation map0 rel3))

test4 = TestCase (assertEqual "makeDerivationMap after 0 inserts (4/4)."
                              Nothing
                              (getDerivation map0 relx))

test5 = TestCase (assertEqual "makeDerivationMap after 1 insert (1/4)."
                              (Just derivation1)
                              (getDerivation map1 rel1))

test6 = TestCase (assertEqual "makeDerivationMap after 1 insert (2/4)."
                              Nothing
                              (getDerivation map1 rel2))

test7 = TestCase (assertEqual "makeDerivationMap after 1 insert (3/4)."
                              Nothing
                              (getDerivation map1 rel3))

test8 = TestCase (assertEqual "makeDerivationMap after 1 insert (4/4)."
                              Nothing
                              (getDerivation map1 relx))

test9 = TestCase (assertEqual "makeDerivationMap after 2 inserts (1/4)."
                              (Just derivation1)
                              (getDerivation map2 rel1))

test10 = TestCase (assertEqual "makeDerivationMap after 2 inserts (2/4)."
                               (Just derivation2)
                               (getDerivation map2 rel2))

test11 = TestCase (assertEqual "makeDerivationMap after 2 inserts (3/4)."
                               Nothing
                               (getDerivation map2 rel3))

test12 = TestCase (assertEqual "makeDerivationMap after 2 inserts (4/4)."
                               Nothing
                               (getDerivation map2 relx))

test13 = TestCase (assertEqual "makeDerivationMap after 3 inserts (1/4)."
                               (Just derivation1)
                               (getDerivation map3 rel1))

test14 = TestCase (assertEqual "makeDerivationMap after 3 inserts (2/4)."
                               (Just derivation2)
                               (getDerivation map3 rel2))

test15 = TestCase (assertEqual "makeDerivationMap after 3 inserts (3/4)."
                               (Just derivation3)
                               (getDerivation map3 rel3))

test16 = TestCase (assertEqual "makeDerivationMap after 3 inserts (4/4)."
                               Nothing
                               (getDerivation map3 relx))

-----------------------------------------------------------------------------------------
-- identifyEquationalRules

equationalRule = RewriteRule word1 word1 True Nothing
orientatedRule = RewriteRule word2 word2 False Nothing

equationalRw = Rewrite equationalRule 0 L2R
orientatedRw = Rewrite orientatedRule 0 L2R

applyRel1Valid = Apply rel1 0 R2L
applyRel2Error = Apply rel2 0 R2L
applyRel2Valid = Apply rel2 0 L2R
applyRel4Valid = Apply rel4 0 R2L
applyRel5Valid = Apply rel5 0 L2R

-- Constructs a graph of derivations.
--
-- Note that ---- denotes an unnamed derivation.
--
-- Vertices and Equationality:
--     rel1: equational
--     rel2: orientated
--     rel3: orientated; invalid use of orientated derived rule
--     rel4: equational
--     rel5: equational
--     rel6: equational
--     rel7: orientated
--     rel8: equational
--     ----: equational
--
-- Dependency Edges:
--     rel3 -> rel2
--     rel4 -> rel1
--     rel5 -> rel1
--     rel6 -> rel4
--     rel6 -> rel5
--     rel7 -> rel5
--     rel8 -> rel5
--     rel8 -> rel2
--     ---- -> rel4
--     ---- -> rel5

rewriteEdge1 :: [AbsRewrite]
rewriteEdge1 = [Left equationalRw, Left equationalRw, Left equationalRw]

rewriteEdge2 :: [AbsRewrite]
rewriteEdge2 = [Left equationalRw, Left orientatedRw, Left orientatedRw]

rewriteEdge3 :: [AbsRewrite]
rewriteEdge3 = [Left orientatedRw, Right applyRel2Error, Left orientatedRw]

rewriteEdge4 :: [AbsRewrite]
rewriteEdge4 = [Left equationalRw, Right applyRel1Valid, Left equationalRw]

rewriteEdge5 :: [AbsRewrite]
rewriteEdge5 = [Left equationalRw, Right applyRel1Valid, Left equationalRw]

rewriteEdge6 :: [AbsRewrite]
rewriteEdge6 = [Left equationalRw,
                Right applyRel4Valid,
                Left equationalRw,
                Right applyRel5Valid,
                Left equationalRw]

rewriteEdge7 :: [AbsRewrite]
rewriteEdge7 = [Left equationalRw, Right applyRel5Valid, Left orientatedRw]

rewriteEdge8 :: [AbsRewrite]
rewriteEdge8 = [Left equationalRw,
                Right applyRel5Valid,
                Left equationalRw,
                Right applyRel2Valid,
                Left equationalRw]

derivationNode1 = AbsDerivation summary1 rewriteEdge1
derivationNode2 = AbsDerivation summary2 rewriteEdge2
derivationNode3 = AbsDerivation summary3 rewriteEdge3
derivationNode4 = AbsDerivation summary4 rewriteEdge4
derivationNode5 = AbsDerivation summary5 rewriteEdge5
derivationNode6 = AbsDerivation summary6 rewriteEdge6
derivationNode7 = AbsDerivation summary7 rewriteEdge7
derivationNode8 = AbsDerivation summary8 rewriteEdge8
derivationNode9 = AbsDerivation nameless rewriteEdge6

proof = [derivationNode1,
         derivationNode2,
         derivationNode3,
         derivationNode4,
         derivationNode5,
         derivationNode6,
         derivationNode7,
         derivationNode8,
         derivationNode9]

dmap = makeDerivationMap proof
emap = identifyEquationalRules dmap

test17 = TestCase (assertEqual "identifyEquationalRules handles equational leaf nodes."
                               (Just True :: Maybe Bool)
                               (emap `isEquationalDerivation` rel1))

test18 = TestCase (assertEqual "identifyEquationalRules handles orientated leaf nodes."
                               (Just False :: Maybe Bool)
                               (emap `isEquationalDerivation` rel2))

test19 = TestCase (assertEqual "identifyEquationalRules handles unknown relations."
                               Nothing
                               (emap `isEquationalDerivation` relx))

test20 = TestCase (assertEqual "identifyEquationalRules internal nodes (1/6)."
                               (Just False :: Maybe Bool)
                               (emap `isEquationalDerivation` rel3))

test21 = TestCase (assertEqual "identifyEquationalRules internal nodes (2/6)."
                               (Just True :: Maybe Bool)
                               (emap `isEquationalDerivation` rel4))

test22 = TestCase (assertEqual "identifyEquationalRules internal nodes (3/6)."
                               (Just True :: Maybe Bool)
                               (emap `isEquationalDerivation` rel5))

test23 = TestCase (assertEqual "identifyEquationalRules internal nodes (4/6)."
                               (Just True :: Maybe Bool)
                               (emap `isEquationalDerivation` rel6))

test24 = TestCase (assertEqual "identifyEquationalRules internal nodes (5/6)."
                               (Just False :: Maybe Bool)
                               (emap `isEquationalDerivation` rel7))

test25 = TestCase (assertEqual "identifyEquationalRules internal nodes (6/6)."
                               (Just False :: Maybe Bool)
                               (emap `isEquationalDerivation` rel8))

-----------------------------------------------------------------------------------------
-- Orchestrates tests.

tests = hUnitTestToTests $ TestList [TestLabel "makeDerivationMap_0Insert_1" test1,
                                     TestLabel "makeDerivationMap_0Insert_2" test2,
                                     TestLabel "makeDerivationMap_0Insert_3" test3,
                                     TestLabel "makeDerivationMap_0Insert_4" test4,
                                     TestLabel "makeDerivationMap_1Insert_1" test5,
                                     TestLabel "makeDerivationMap_1Insert_2" test6,
                                     TestLabel "makeDerivationMap_1Insert_3" test7,
                                     TestLabel "makeDerivationMap_1Insert_4" test8,
                                     TestLabel "makeDerivationMap_2Insert_1" test9,
                                     TestLabel "makeDerivationMap_2Insert_2" test10,
                                     TestLabel "makeDerivationMap_2Insert_3" test11,
                                     TestLabel "makeDerivationMap_2Insert_4" test12,
                                     TestLabel "makeDerivationMap_3Insert_1" test13,
                                     TestLabel "makeDerivationMap_3Insert_2" test14,
                                     TestLabel "makeDerivationMap_3Insert_3" test15,
                                     TestLabel "makeDerivationMap_3Insert_4" test16,
                                     TestLabel "identifyEquationalRules_Eq_Leaf" test17,
                                     TestLabel "identifyEquationalRules_Or_Leaf" test18,
                                     TestLabel "identifyEquationalRules_Unknown" test19,
                                     TestLabel "identifyEquationalRules_Int_1" test20,
                                     TestLabel "identifyEquationalRules_Int_2" test21,
                                     TestLabel "identifyEquationalRules_Int_3" test22,
                                     TestLabel "identifyEquationalRules_Int_4" test23,
                                     TestLabel "identifyEquationalRules_Int_5" test24,
                                     TestLabel "identifyEquationalRules_Int_6" test25]

main = defaultMain tests
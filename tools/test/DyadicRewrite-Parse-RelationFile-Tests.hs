module Main where

import Test.Framework
import Test.Framework.Providers.HUnit
import Test.HUnit
import Data.Maybe
import Data.Either
import DyadicRewrite.Common
import DyadicRewrite.Rewrite.Rules
import DyadicRewrite.Parse.Common
import DyadicRewrite.Parse.RelationFile

-----------------------------------------------------------------------------------------
-- parseRelation

circ1a :: Circuit
circ1a = [(Gate "a1" []), (Gate "a2" []), (Gate "a3" [])]

circ2a :: Circuit
circ2a = [(Gate "abc" []), (Gate "def" [1]), (Gate "ghi" [1, 2])]

circ1b :: Circuit
circ1b = [(Gate "a1" []), (Gate "a2" [])]

circ2b :: Circuit
circ2b = [(Gate "abc" []), (Gate "def" [1]), (Gate "ghi" [1, 2]), (Gate "a3" [])]

test1 = TestCase (assertEqual "Tests that empty strings are rejected."
                              (Left (Right RelMissingLHS))
                              (parseRelation ""))

test2 = TestCase (assertEqual "Tests that missing left-hand sides are rejected."
                              (Left (Right RelMissingLHS))
                              (parseRelation "1abc"))

test3 = TestCase (assertEqual "Tests that missing relation operations are detected."
                              (Left (Right (InvalidRelType 8)))
                              (parseRelation "a1.a2.a3"))

test4 = TestCase (assertEqual "Tests that bad relation types are detected."
                              (Left (Right (InvalidRelType 8)))
                              (parseRelation "a1.a2.a3 #"))

test5 = TestCase (assertEqual "Tests that missing right-hand sides are rejected."
                              (Left (Right RelMissingRHS))
                              (parseRelation "a1.a2.a3 ="))

test6 = TestCase (assertEqual "Tests bad right-hand sides are rejected."
                              (Left (Right RelMissingRHS))
                              (parseRelation "a1.a2.a3 = 1abc"))

test7 = TestCase (assertEqual "Tests bad right-hand sides are rejected."
                              (Left (Left (UnexpectedSymbol 31)))
                              (parseRelation "a1.a2.a3 = abc.def[1].ghi[1][2]  bad"))

test8 = TestCase (assertEqual "Tests that equational relations are parsed (1/2)."
                              (Right (RewriteRule circ1a circ2a True False))
                              (parseRelation "a1.a2.a3 = abc.def[1].ghi[1][2] "))

test9 = TestCase (assertEqual "Tests that equational relations are parsed (2/2)."
                              (Right (RewriteRule circ1b circ2b True False))
                              (parseRelation "a1.a2 = abc.def[1].ghi[1][2].a3 "))

test10 = TestCase (assertEqual "Tests that production rules are parsed (1/2)."
                               (Right (RewriteRule circ1a circ2a False False))
                               (parseRelation "a1.a2.a3 → abc.def[1].ghi[1][2] "))

test11 = TestCase (assertEqual "Tests that production rules are parsed (2/2)."
                               (Right (RewriteRule circ1b circ2b False False))
                               (parseRelation "a1.a2 → abc.def[1].ghi[1][2].a3 "))

test12 = TestCase (assertEqual "Tests that relations between empty strings are parsed."
                               (Right (RewriteRule [] [] False False))
                               (parseRelation "ε → ε "))

-----------------------------------------------------------------------------------------
-- parseRelationDefn

test13 = TestCase (assertEqual "Tests that bad relation names are rejected."
                               (Left (Right InvalidRelName))
                               (parseRelationDefn "1ab ε → ε"))

test14 = TestCase (assertEqual "Tests that bad relations are rejected (no position)."
                               (Left (Right RelMissingRHS))
                               (parseRelationDefn "rel1 a1.a2.a3 ="))

test15 = TestCase (assertEqual "Tests that bad relations are rejected (positional)."
                               (Left (Left (UnexpectedSymbol 18)))
                               (parseRelationDefn "rel1 a.b.c = b.c.a  x"))

test16 = TestCase (assertEqual "Tests that spaces are required after an identifier."
                               (Left (Left (UnexpectedSymbol 4)))
                               (parseRelationDefn "rel1ε → ε"))

test17 = TestCase (assertEqual "Tests that equational relations are parsed (1/2)."
                               (Right ("rel1", (RewriteRule circ1a circ1b True False)))
                               (parseRelationDefn "  rel1 a1.a2.a3   =  a1.a2  "))

test18 = TestCase (assertEqual "Tests that equational relations are parsed (2/2)."
                               (Right ("rel2", (RewriteRule circ1b circ1a True False)))
                               (parseRelationDefn "  rel2   a1.a2   =  a1.a2.a3  "))

-----------------------------------------------------------------------------------------
-- Orchestrates tests.

tests = hUnitTestToTests $ TestList [TestLabel "parseRelation_EmptyString" test1,
                                     TestLabel "parseRelation_NoLHS" test2,
                                     TestLabel "parseRelation_NoRelOp" test3,
                                     TestLabel "parseRelation_BadRelOp" test4,
                                     TestLabel "parseRelation_NoRHS" test5,
                                     TestLabel "parseRelation_BadRHS" test6,
                                     TestLabel "parseRelation_BadEndOfLine" test7,
                                     TestLabel "parseRelation_EquationalOne" test8,
                                     TestLabel "parseRelation_EquationalTwo" test9,
                                     TestLabel "parseRelation_ProductionOne" test10,
                                     TestLabel "parseRelation_ProductionTwo" test11,
                                     TestLabel "parseRelation_EmptyStrings" test12,
                                     TestLabel "parseRelationDefn_BadName" test13,
                                     TestLabel "parseRelationDefn_NoPosRelErr" test14,
                                     TestLabel "parseRelationDefn_PosRelErr" test15,
                                     TestLabel "parseRelationDefn_SpaceAfterID" test16,
                                     TestLabel "parseRelationDefn_GoodRelOne" test17,
                                     TestLabel "parseRelationDefn_GoodRelTwo" test18]

main = defaultMain tests

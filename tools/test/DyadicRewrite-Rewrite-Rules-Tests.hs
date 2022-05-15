module Main where

import Test.HUnit
import DyadicRewrite.Common
import DyadicRewrite.Rewrite.Rules

-----------------------------------------------------------------------------------------
-- Tests when a rewrite rule is applicable (in either direction).

circuit1a :: Circuit
circuit1a = ["CCX123", "CX13", "CX23"]

circuit1b :: Circuit
circuit1b = ["CX13", "CCX123", "CX23"]

rule1 :: RewriteRule
rule1 = RewriteRule ["CCX123", "CX13"] ["CX13", "CCX123"]

test1 :: Test
test1 = TestCase (assertBool "Can apply CCX123.CX13 = CX13.CCX123 to CCX123.CX13.CX23"
                             (checkRewriteRule circuit1a rule1 True))

test2 :: Test
test2 = TestCase (assertBool "Can apply CCX123.CX13 = CX13.CCX123 to CX13.CCX123.CX23"
                             (checkRewriteRule circuit1b rule1 False))

test3 :: Test
test3 = TestCase (assertEqual "CCX123.CX13.CX23 =R1=> CX13.CCX123.CX23"
                              circuit1b
                              (applyRewriteRule circuit1a rule1 True))

test4 :: Test
test4 = TestCase (assertEqual "CX13.CCX123.CX23 =R1=> CCX123.CX13.CX23"
                              circuit1a
                              (applyRewriteRule circuit1b rule1 False))

-----------------------------------------------------------------------------------------
-- Tests when a rewrite rule is not applicable.

rule2 :: RewriteRule
rule2 = RewriteRule ["CCX123", "CX13", "CX23", "CX12"] ["CCX123", "CX13", "CX23", "CX12"]

rule3 :: RewriteRule
rule3 = RewriteRule ["CX123", "CX23"] ["CX23", "CX123"]

test5 :: Test
test5 = TestCase (assertBool "The rule is too long and must be rejected"
                             (not (checkRewriteRule circuit1a rule2 True)))

test6 :: Test
test6 = TestCase (assertBool "The rule does not match and must be rejected"
                             (not (checkRewriteRule circuit1a rule3 True)))

-----------------------------------------------------------------------------------------
-- Tests when a rewrite operation is applicable (in either direction).

circuit2a :: Circuit
circuit2a = ["X1", "X2", "Z1", "CCX123", "CX13", "CX23"]

circuit2b :: Circuit
circuit2b = ["X1", "X2", "Z1", "CX13", "CCX123", "CX23"]

op1a :: RewriteOp
op1a = RewriteOp rule1 3 True

op1b :: RewriteOp
op1b = RewriteOp rule1 3 False

test7 :: Test
test7 = TestCase (assertBool "Can apply CCX123.CX13 = CX13.CCX123 forward at index 3"
                             (checkRewriteOp circuit2a op1a))

test8 :: Test
test8 = TestCase (assertBool "Can apply CCX123.CX13 = CX13.CCX123 backwards at index 3"
                             (checkRewriteOp circuit2b op1b))

test9 :: Test
test9 = TestCase (assertEqual
                  "X1.X2.Z1.CCX123.CX13.CX23 =(R1 at 3)=> X1.X2.Z1.CX13.CCX123.CX23"
                  circuit2b
                  (applyRewriteOp circuit2a op1a))

test10 :: Test
test10 = TestCase (assertEqual
                   "X1.X2.Z1.CX13.CCX123.CX23 =(R1 at 3)=> X1.X2.Z1.CCX123.CX13.CX23"
                   circuit2a
                   (applyRewriteOp circuit2b op1b))

circuit3a :: Circuit
circuit3a = ["K12", "X1", "X2", "Z1", "CCX123", "CX13", "CX23"]

circuit3b :: Circuit
circuit3b = ["K12", "X1", "X2", "Z1", "CX13", "CCX123", "CX23"]

op2a :: RewriteOp
op2a = RewriteOp rule1 4 True

op2b :: RewriteOp
op2b = RewriteOp rule1 4 False

test11 :: Test
test11 = TestCase (assertBool "Can apply CCX123.CX13 = CX13.CCX123 forward at index 4"
                             (checkRewriteOp circuit3a op2a))

test12 :: Test
test12 = TestCase (assertBool "Can apply CCX123.CX13 = CX13.CCX123 backwards at index 4"
                             (checkRewriteOp circuit3b op2b))

test13 :: Test
test13 = TestCase (assertEqual
                   "K12.X1.X2.Z1.CCX123.CX13.CX23 =(R1 at 4)=> X1.X2.Z1.CX13.CCX123.CX23"
                   circuit3b
                   (applyRewriteOp circuit3a op2a))

test14 :: Test
test14 = TestCase (assertEqual
                   "K12.X1.X2.Z1.CX13.CCX123.CX23 =(R1 at 4)=> X1.X2.Z1.CCX123.CX13.CX23"
                   circuit3a
                   (applyRewriteOp circuit3b op2b))

-----------------------------------------------------------------------------------------
-- Tests edge cases with empty strings.

circuit4a :: Circuit
circuit4a = ["CCX123", "CCX123"]

circuit4b :: Circuit
circuit4b = []

rule4 :: RewriteRule
rule4 = RewriteRule ["CCX123", "CCX123"] []

test15 :: Test
test15 = TestCase (assertEqual "Can support rules that eliminate symbols"
                               circuit4b
                               (applyRewriteRule circuit4a rule4 True))

test16 :: Test
test16 = TestCase (assertEqual "Can support rules that introduce symbols"
                               circuit4a
                               (applyRewriteRule circuit4b rule4 False))

-----------------------------------------------------------------------------------------
-- Orchestrates tests.

tests :: Test
tests = TestList [TestLabel "CheckRuleForwards" test1,
                  TestLabel "CheckRuleBackwards" test2,
                  TestLabel "ApplyRuleForwards" test3,
                  TestLabel "ApplyRuleBackwards" test4,
                  TestLabel "RuleTooLong" test5,
                  TestLabel "RuleDoesNotMatch" test6,
                  TestLabel "CheckOpAt3Forwards" test7,
                  TestLabel "CheckOpAt3Backwards" test8,
                  TestLabel "ApplyOpAt3Forwards" test9,
                  TestLabel "ApplyOpAt3Backwards" test10,
                  TestLabel "CheckOpAt4Forwards" test11,
                  TestLabel "CheckOpAt4Backwards" test12,
                  TestLabel "ApplyOpAt4Forwards" test13,
                  TestLabel "ApplyOpAt4Backwards" test14,
                  TestLabel "ApplyElimination" test15,
                  TestLabel "ApplyIntroduce" test16]

main :: IO Counts
main = runTestTT tests

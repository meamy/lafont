-- | Command-line application to relation inversion.

module Main where

import System.Environment
import System.IO
import Tietze.Common
import Tietze.Edit.Invert
import TietzeExe.IO.Configs
import TietzeExe.InvertRule
import InvertRule.CmdLn

-- | Helper method to pass configurations to doInversion.
runTool :: Config -> InvertRule -> IO ()
runTool conf args = doInversion stdout gens rels ders query
    where gens  = generators conf
          rels  = relations conf
          ders  = derivations conf
          query = InvQuery (relname args) (leftInv args) (policy args)

-- | Parses and validates arguments before calling doInversion.
main = do
    args <- getCmdArgs
    res  <- parseConfigYaml $ configs args
    case res of
        Left err   -> putStrLn $ printConfigErr err
        Right conf -> runTool conf args

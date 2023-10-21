-- | Test file for yaml configuration parsing.

module Main where

import System.Environment
import System.IO
import LafontExe.IO.Configs
import YamlTest.CmdLn

-- | Parses and validates arguments before calling parseConfigYamlImpl.
main = do
    args <- getCmdArgs
    res  <- parseConfigYamlImpl $ configs args
    case res of
        Left err   -> putStrLn $ printConfigErr err
        Right conf -> do
            putStrLn "Configuration File Summary"
            putStrLn $ "Generator File:   " ++ (show . generators) conf
            putStrLn $ "Relation File:    " ++ (show . relations) conf
            putStrLn $ "Derivation Files: " ++ (show . derivations) conf
            putStrLn $ "Obligations:      " ++ (show . obligations) conf

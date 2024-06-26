-- | Command-line application to relation inversion.

module Main where

import Data.List.Split
import System.Environment
import System.IO
import Tietze.Common
import TietzeExe.GraphDeps
import TietzeExe.IO.Configs
import GraphDeps.CmdLn

-- | Helper method to pass configurations to graphDeps.
runTool :: Config -> Style -> GraphDeps -> IO ()
runTool conf sty args = graphDeps stdout sty types gens rels ders
    where gens  = generators conf
          rels  = relations conf
          ders  = derivations conf
          types = splitOn "," $ tsources args

-- | Helper method to format ConfigErr with the offending file.
printErr :: String -> ConfigErr -> String
printErr file err = tag ++ printConfigErr err
    where tag = "[" ++ file ++ "] "

-- | Helper method to parse a configuration file, with error handling.
parseConf :: String -> IO (Either String Config)
parseConf file = do
    res <- parseConfigYaml file
    case res of
        Left err   -> return $ Left $ printErr file err
        Right conf -> return $ Right conf

-- | Helper method to parse a styling file, with error handling.
parseStyle :: Maybe String -> IO (Either String Style)
parseStyle Nothing     = return $ Right defaultStyle
parseStyle (Just file) = do
    res <- parseStyleYaml file
    case res of
        Left err  -> return $ Left $ printErr file err
        Right sty -> return $ Right sty

-- | Parses and validates arguments before calling graphDeps.
main = do
    args <- getCmdArgs
    res1 <- parseConf $ configs args
    res2 <- parseStyle $ style args
    case res1 of
        Left err   -> putStrLn err
        Right conf -> case res2 of
            Left err  -> putStrLn err
            Right sty -> runTool conf sty args

{-# LANGUAGE DeriveGeneric #-}

-- | Helper functions to interace with yaml configurations.

module LafontExe.IO.Configs where

import           Data.Aeson.Types
import           Data.List.NonEmpty
import qualified Data.Map           as Map
import           Data.Text
import           Data.Yaml
import           GHC.Generics
import           Lafont.Format.GraphViz

-----------------------------------------------------------------------------------------
-- * Representation of Proof Configurations.

-- | Data type to store the contents of a configuration file.
data Config = Config { generators  :: String
                     , relations   :: NonEmpty String
                     , derivations :: [String]
                     , obligations :: [String]
                     } deriving (Generic, Show, Eq)
instance FromJSON Config

-----------------------------------------------------------------------------------------
-- * Representation of Stylings.

instance FromJSON X11Color where
    parseJSON (String str) =
        case toColour $ unpack str of
            Left err -> prependFailure "parsing X11Color failed: " (fail $ display err)
            Right c  -> return c
    
    parseJSON invalid = prependFailure "parsing X11Color failed, " err
        where err = typeMismatch "String" invalid

-- | A mapping from derivation type to associated colours.
type ColorMap = Map.Map String X11Color

-- | Data type to store the contents of a style file.
data Style = Style { color :: ColorMap
                   } deriving (Generic, Show, Eq)
instance FromJSON Style

-- | Returns the default styling for Lafont output.
defaultStyle :: Style
defaultStyle = Style { color = Map.empty }

-----------------------------------------------------------------------------------------
-- * YAML Error Wrapper.

-- | Configuration parsing error wrapper.
data ConfigErr = YamlErr ParseException

-- | Utility to pretty print a configuration parsing error.
printConfigErr :: ConfigErr -> String
printConfigErr (YamlErr err) = prettyPrintParseException err

-----------------------------------------------------------------------------------------
-- * Parsing Configurations.

-- | Takes as input the name of a file. When specialized to a FromJSON type a, the file
-- is validated against the JSON structure of a. If the file is valid, then returns the
-- corresponding JSON object as an instance of type a. Otherwise, a parsing error is
-- returned.
parseYamlAsJSON :: (FromJSON a) => String -> IO (Either ConfigErr a)
parseYamlAsJSON fname = do
    res <- decodeFileEither fname
    case res of
        Left err   -> return $ Left $ YamlErr err
        Right conf -> return $ Right conf

-- | Takes as input the name of a configuration file. If the file is valid, then returns
-- a summary of the configurations. Otherwise, a parsing error is returned.
parseConfigYamlImpl :: String -> IO (Either ConfigErr Config)
parseConfigYamlImpl = parseYamlAsJSON

-- | Takes as input the name of a style file. If the file is valid, then returns a
-- summary of the styling choices. Otyherwise, a parsing error is returned.
parseStyleYamlImpl :: String -> IO (Either ConfigErr Style)
parseStyleYamlImpl = parseYamlAsJSON

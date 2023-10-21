-- | Utilities to implement a parser for a Quoptomize executable.
--
-- Adapted from: https://github.com/onestruggler/qasm-quipper/

module LafontExe.IO.CmdLnParser
  ( Data
  , Typeable
  , addModeAnnotations
  , parseCmdLnArgs
  ) where

-------------------------------------------------------------------------------
-- * Import Section.

import System.Console.CmdArgs
  ( Data
  , Typeable
  , (&=)
  , cmdArgs
  , cmdArgsMode
  , cmdArgsRun
  , details
  , explicit
  , help
  , helpArg
  , modes
  , name
  , summary
  , verbosityArgs
  , versionArg
  )

-------------------------------------------------------------------------------
-- * Static Application Data.

-- | The current version number for executables.
_VERSION :: String
_VERSION = "1.0.0"

-------------------------------------------------------------------------------
-- * Annotations for Modes.

-- | Takes as input a human-readable name for a mode (title), a description of
-- the mode (desc), and the mode itself (ctor). Annotates the mode with a
-- multiline description, in which the first line indicates the name of the
-- mode, and the section line describes the mode.
--
-- The multiline description will appear as follows.
--   <prog> <mode> <options...>
--   
--   <list of flags...>
--   
--   <title> Details:
--   <desc>
-- As before, common flags are factored out.
--
-- Note: This function is intended for multimodal command-line parsers.
addModeAnnotations :: (Data a) => String -> String -> a -> a
addModeAnnotations title desc ctor = ctor &= details [header, desc]
    where header = title ++ " Details:"

-------------------------------------------------------------------------------
-- * Command-line Parsing Functions.

-- | Helper functions to apply standard annotations to a command-line parser.
-- Takes as input a human-readable name for the application (title), and a
-- one-line description of the application (desc). Returns a command-line
-- parser with an auto-generated version command (-v, --version), an
-- auto-generated help command (-h, --help), and an up-to-date version number.
addParserAnnotations :: (Data a) => String -> String -> a -> a
addParserAnnotations title desc parser = parser
    &= summary info
    &= help desc
    &= versionArg [explicit, name "version", name "v", summary _VERSION]
    &= verbosityArgs [explicit, name "Verbose", name "V"] []
    &= helpArg [explicit, name "help", name "h"]
    where info = title ++ " version " ++ _VERSION

-- | Takes as input a human-readable application name (title), a one-line
-- description of the application (desc), and a non-empty list of modes for the
-- application (ctors). Returns a command-line argument parser with an
-- auto-generated version command (-v, --version), an autogenerated help
-- command (-h, --help), and an up-to-date version number.
--
-- The parser returned by this function may be hierarchical. In particular, if
-- ctors contains a single mode (ctor), then the parser will default to reading
-- the fields of ctor. If ctors contains multiple modes, each from a different
-- constructor, then the parser will instantiate a sub-parser for each mode.
-- The name of each mode is the name of the corresponding constructor. In
-- either case, the help command will contain an entry for the fields of each
-- mode. If two or more modes share the same field, then these fields will be
-- combined in the help text.
--
-- Note: If ctors is empty, then an error is returned.
parseCmdLnArgs :: (Data a, Typeable a) => String -> String -> [a] -> IO a
parseCmdLnArgs title desc ctors =
    case ctors of
        []     -> error "Command-line parser requires at least one ctor."
        [ctor] -> cmdArgs $ annotate ctor
        _      -> cmdArgsRun $ cmdArgsMode $ annotate $ modes ctors
    where annotate = addParserAnnotations title desc

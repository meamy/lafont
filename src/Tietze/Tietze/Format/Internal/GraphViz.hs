-- | Implementation details for GraphViz.

module Tietze.Format.Internal.GraphViz
  ( DotParseError (..)
  , NodeID (..)
  , X11Color (..)
  ) where

-----------------------------------------------------------------------------------------
-- * Conversion Errors.

-- | Errors corresponding to invalid characters in an X11Color.
data DotParseError = UpperCase Char
                   | UnexpectedChar Char
                   | EmptyToken
                   deriving (Show, Eq)

-----------------------------------------------------------------------------------------
-- * Valid Vertex Name.

-- | A wrapper type for strings which also form valid NodeID's. This type permits a
-- restricted set of the NodeID types supported by the Dot file format. For example, the
-- HTML string format is not supported. In particular, NodeID strings may consist of only
-- alphanumeric symbols and underscores.
newtype NodeID = NodeID String deriving (Show, Eq, Ord)

-----------------------------------------------------------------------------------------
-- * Valid Colour Name.

-- | A wrapper type for the X11Color strings supported by the Dot file format.
newtype X11Color = X11Color String deriving (Show, Eq)

-- | Provides an interface to format derivations in LaTeX.

module Tietze.Format.LaTeX
  ( MacroList
  , makeGenMacros
  , makeRelMacros
  , printFormattedLine
  , printFormattedProof
  , printFormattedStep
  , printMacroList
  ) where
 
-----------------------------------------------------------------------------------------
-- * Import Section.

import qualified Data.Map as Map

import Data.Char
  ( chr
  , ord
  )
import Tietze.Common
  ( MonWord
  , Symbol (..)
  )
import Tietze.Format.Common
  ( FormattedLine (..)
  , FormattedProof (..)
  , FormattedStep (..)
  , flength
  )
import Tietze.Rewrite.Common (RuleDir (..))
import Tietze.Rewrite.Lookup
  ( RuleDict
  , toRuleNames
  )
import Tietze.Rewrite.Rules (RuleSource (..))

-----------------------------------------------------------------------------------------
-- * GenMacro Dictionary.

-- | Describes a newcommand definition which associates a derivational symbol with its
-- math mode representation. For example, (MacroDef lft_SWAP01 X_0) maps the generator
-- SWAP01 to the symbol X_0 through a macro called lft_SAWP01.
data MacroDef = MacroDef String String deriving (Show, Eq)

-- | Maintains a mapping from derivational symbol names to macro definitions. Each macro
-- definition allows an end-user to decide the math mode representation associated with
-- each symbol in the LaTeX depiction of a derivation. In terms of LaTeX source code,
-- this component is a list of newcommand statements.
newtype MacroList = MacroList (Map.Map String MacroDef) deriving (Show, Eq)

-- | Prints a single macro definition as a newcommand statement.
printMacroDef :: MacroDef -> String
printMacroDef (MacroDef cmd sym) = "\\newcommand{" ++ cmd ++ "}{" ++ sym ++ "}"

-- | Prints a MacroList as a list of newcommand statements, which each statement has a
-- comment relating the macro to its designated generator symbol.
printMacroList :: MacroList -> String
printMacroList (MacroList map) = Map.foldrWithKey f "" map
    where f gen def res = let comment = "% Macro for: " ++ gen 
                          in comment ++ "\n" ++ printMacroDef def ++ "\n" ++ res

-- | Converts integers to LaTeX macro friendly symbols.
formatMacroID :: Int -> String
formatMacroID n
    | q > 0     = c ++ formatMacroID q
    | otherwise = c
    where r = n `mod` 26
          q = n `quot` 26
          c = [chr $ ord 'A' + r]

-- | Implementation details for makeGenMacros. Consumes the alphabet corresponding to a
-- generator dictionary. Returns the raw map encapsulated by a MacroDef.
makeGenMacrosImpl :: [String] -> Map.Map String MacroDef
makeGenMacrosImpl []         = Map.empty
makeGenMacrosImpl (gen:gens) = Map.insert gen def map
    where map = makeGenMacrosImpl gens
          idx = Map.size map
          cmd = "\\lftgen" ++ formatMacroID idx
          sym = "X_{" ++ show idx ++ "}"
          def = MacroDef cmd sym

-- | Constructs the MacroList corresponding to a generator dictionary. Note that for each
-- LaTeX document, only one MacroList should be generated. Otherwise, the macro names or
-- corresponding math mode symbols may conflict.
makeGenMacros :: [String] -> MacroList
makeGenMacros = MacroList . makeGenMacrosImpl

-- | Implementation details for makeRelMacros. Consumes the list of rule names
-- corresponding to a rule dictionary. Returns the raw map encapsulated by a MacroDef.
makeRelMacrosImpl :: [String] -> Map.Map String MacroDef
makeRelMacrosImpl []         = Map.empty
makeRelMacrosImpl (rel:rels) = Map.insert rel def map
    where map = makeRelMacrosImpl rels
          idx = Map.size map
          cmd = "\\lftrel" ++ formatMacroID idx
          sym = "R_{" ++ show idx ++ "}"
          def = MacroDef cmd sym

-- | Constructs the MacroList corresponding to a rule dictionary. Assumes that all
-- derived relations are included in the dictionary. Note that for each LaTeX document,
-- only one MacroList should be generated. Otherwise, the macro names or corresponding
-- math mode symbols may conflict.
makeRelMacros :: RuleDict -> MacroList
makeRelMacros = MacroList . makeRelMacrosImpl . toRuleNames

-----------------------------------------------------------------------------------------
-- * FormattedLine Printing.

-- | Returns the macro symbol associated with a generator symbol. If no generator symbol
-- can be found, then the \lftgenerr macro is returned.
symbolToMacro :: MacroList -> Symbol -> String
symbolToMacro (MacroList map) sym =
    case Map.lookup (name sym) map of
        Just (MacroDef cmd _) -> cmd
        Nothing               -> "\\lftgenerr"

-- | Implements printFormattedLine for a specific MonWord fragment.
printFormattedLineImpl :: MacroList -> MonWord -> String
printFormattedLineImpl _      []         = "\\epsilon"
printFormattedLineImpl macros [sym]      = symbolToMacro macros sym
printFormattedLineImpl macros (sym:word) = symbolToMacro macros sym ++ " \\cdot " ++ rest
    where rest = printFormattedLineImpl macros word

-- | Takes as input a mapping from generator symbols to macro symbols, together with a
-- formatted line. Returns the corresponding LaTeX line.
printFormattedLine :: MacroList -> FormattedLine -> String
printFormattedLine macros (NoEditLine word) = line
    where line = printFormattedLineImpl macros word
printFormattedLine macros (AddThenElimLine w1 w2 w3) = l1 ++ tar ++ l3
    where tar = "\\underline{\\overline{" ++ printFormattedLineImpl macros w2 ++ "}}"
          l1  = if null w1 then "" else printFormattedLineImpl macros w1 ++ " \\cdot "
          l3  = if null w3 then "" else " \\cdot " ++ printFormattedLineImpl macros w3
printFormattedLine macros (ElimLine w1 w2 w3) = l1 ++ elim ++ l3
    where elim = "\\underline{" ++ printFormattedLineImpl macros w2 ++ "}"
          l1   = if null w1 then "" else printFormattedLineImpl macros w1 ++ " \\cdot "
          l3   = if null w3 then "" else " \\cdot " ++ printFormattedLineImpl macros w3
printFormattedLine macros (AddLine w1 w2 w3) = l1 ++ add ++ l3
    where add = "\\overline{" ++ printFormattedLineImpl macros w2 ++ "}"
          l1  = if null w1 then "" else printFormattedLineImpl macros w1 ++ " \\cdot "
          l3  = if null w3 then "" else " \\cdot " ++ printFormattedLineImpl macros w3
printFormattedLine macros (AddElimSplitLine w1 w2 w3 w4 w5) = add ++ " \\cdot " ++ elim
    where add  = printFormattedLine macros (AddLine w1 w2 w3)
          elim = printFormattedLine macros (ElimLine [] w4 w5)
printFormattedLine macros (ElimAddSplitLine w1 w2 w3 w4 w5) = elim ++ " \\cdot " ++ add
    where elim = printFormattedLine macros (ElimLine w1 w2 w3)
          add  = printFormattedLine macros (AddLine [] w4 w5)
printFormattedLine macros (ElimOverAddLine w1 w2 w3 w4 w5) = l1 ++ outer ++ l5
    where inner = printFormattedLine macros (AddLine w2 w3 w4)
          outer = "\\underline{" ++ inner ++ "}"
          l1    = if null w1 then "" else printFormattedLineImpl macros w1 ++ " \\cdot "
          l5    = if null w5 then "" else " \\cdot " ++ printFormattedLineImpl macros w5
printFormattedLine macros (AddOverElimLine w1 w2 w3 w4 w5) = l1 ++ outer ++ l5
    where inner = printFormattedLine macros (ElimLine w2 w3 w4)
          outer = "\\overline{" ++ inner ++ "}"
          l1    = if null w1 then "" else printFormattedLineImpl macros w1 ++ " \\cdot "
          l5    = if null w5 then "" else " \\cdot " ++ printFormattedLineImpl macros w5
printFormattedLine macros (ElimAddOverlapLine w1 w2 w3 w4 w5) = l1 ++ olap ++ l5
    where elim = "\\UOLunderline{" ++ printFormattedLineImpl macros w2 ++ " \\cdot}"
          mid  = "[" ++ printFormattedLineImpl macros w3 ++ "]"
          add  = "\\UOLoverline{\\cdot " ++ printFormattedLineImpl macros w4 ++ "}"
          olap = elim ++ mid ++ add
          l1   = if null w1 then "" else printFormattedLineImpl macros w1 ++ " \\cdot "
          l5   = if null w5 then "" else " \\cdot " ++ printFormattedLineImpl macros w5
printFormattedLine macros (AddElimOverlapLine w1 w2 w3 w4 w5) = l1 ++ olap ++ l5
    where add  = "\\UOLoverline{" ++ printFormattedLineImpl macros w2 ++ " \\cdot}"
          mid  = "[" ++ printFormattedLineImpl macros w3 ++ "]"
          elim = "\\UOLunderline{\\cdot " ++ printFormattedLineImpl macros w4 ++ "}"
          olap = add ++ mid ++ elim
          l1   = if null w1 then "" else printFormattedLineImpl macros w1 ++ " \\cdot "
          l5   = if null w5 then "" else " \\cdot " ++ printFormattedLineImpl macros w5

-----------------------------------------------------------------------------------------
-- * FormattedStep Printing.

-- | Returns the macro symbol associated with a relation symbol. If no relation symbol
-- can be found, then the \lftrelerr macro is returned.
relationToMacro :: MacroList -> RuleSource -> String
relationToMacro (MacroList map) (Primitive name) =
    case Map.lookup name map of
        Just (MacroDef cmd _) -> cmd
        Nothing               -> "\\lftrelerr"
relationToMacro _     (Derived Nothing)     = "\\lftrelerr"
relationToMacro macro (Derived (Just name)) = relationToMacro macro $ Primitive name

-- | Takes as input a mapping from generator symbols to macro symbols, a mapping from
-- relation symbols to macro symbols, and a formatted step. Returns the corresponding
-- LaTeX line.
printFormattedStep :: MacroList -> MacroList -> FormattedStep -> String
printFormattedStep gmacros rmacros (FormattedStep src dir line) = stext
    where macro = relationToMacro rmacros src
          arrow = if dir == L2R then "\\xrightarrow" else "\\xleftarrow"
          ltext = printFormattedLine gmacros line
          stext = arrow ++ "{" ++ macro ++  "}" ++ " " ++ ltext

-----------------------------------------------------------------------------------------
-- * FormattedProof Printing.

-- | Returns true if the initial line in a FormattedProof is too long for arrows midline.
isWordLong :: FormattedLine -> Bool
isWordLong line = flength line >= 5

-- | Implementation details for printProofStep.
printProofStepImpl :: Bool -> MacroList -> MacroList -> FormattedStep -> String
printProofStepImpl islong gmacros rmacros step
    | islong    = "&\\qquad" ++ text
    | otherwise = "&" ++ text
    where text = printFormattedStep gmacros rmacros step

-- | Handling the formatting of proof steps, including line breaks and length-based
-- alignment decisions.
printProofStep :: Bool -> MacroList -> MacroList -> [FormattedStep] -> String
printProofStep _      _       _       []     = ""
printProofStep islong gmacros rmacros [step] = text ++ "\n"
    where text = printProofStepImpl islong gmacros rmacros step
printProofStep islong gmacros rmacros (step:steps) = text ++ " \\\\" ++ "\n" ++ rest
    where text = printProofStepImpl islong gmacros rmacros step
          rest = printProofStep islong gmacros rmacros steps

-- | Handles the formatting of the initial word, including line breaks and length-based
-- alignment decisions.
printProofInitWord :: Bool -> MacroList -> FormattedLine -> String
printProofInitWord islong gmacros word
    | islong    = "&" ++ text ++ " \\\\"
    | otherwise = text
    where text = printFormattedLine gmacros word

-- | Takes as input a mapping from generator symbols to macro symbols, a mapping from
-- relation symbols to macro symbols, and a formatted derivational proof. Returns the
-- corresponding LaTeX alignment block.
printFormattedProof :: MacroList -> MacroList -> FormattedProof -> String
printFormattedProof gmacros rmacros (FormattedProof initWord steps) = result
    where islong = isWordLong initWord
          fstart = printProofInitWord islong gmacros initWord
          fsteps = printProofStep islong gmacros rmacros steps
          aligns = fstart ++ "\n" ++ fsteps
          result = "\\begin{align*}" ++ "\n" ++ aligns ++ "\\end{align*}"

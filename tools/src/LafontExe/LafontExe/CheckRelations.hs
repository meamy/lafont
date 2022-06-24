-- | Implementation of check_relations.

module LafontExe.CheckRelations where

import System.IO
import Lafont.Rewrite.Lookup
import Lafont.Parse.GeneratorFile
import Lafont.Parse.RelationFile
import LafontExe.IO.Files
import LafontExe.Logging.LineBased
import LafontExe.Logging.Primitive

-----------------------------------------------------------------------------------------
-- * Logic.

-- | Consumes the name of a relation file (fname), a list of known generators (gens), and
-- the lines of the relation file (lines). If the lines parse correctly with respect to
-- gens, then returns a textual representation of the relations. Otherwise, the textual
-- representation of a parsing error is returned.
processRelationFile :: String -> [String] -> [String] -> String
processRelationFile fname gens lines =
    case (parseRelFile gens lines 0) of
        (Left (errLn, err)) -> logEitherMsg fname errLn err
        (Right dict)        -> foldRules (\g str -> (logRule g) ++ "\n" ++ str) "" dict

-- | See checkRelations. Requires that both files exist, whereas checkRelations does not
-- imporse this assumption
checkRelationsImpl :: Handle -> String -> String -> IO ()
checkRelationsImpl hdl genFname relFname = do
    gContent <- readFile genFname
    rContent <- readFile relFname
    case (parseGenFileAsAlphabet (lines gContent) 0) of
        Left (errLn, err) -> hPutStr hdl (logEitherMsg genFname errLn err)
        Right gens        -> hPutStr hdl (processRelationFile relFname gens (lines rContent))

-- | Consumes a handle, the name of a generator file (genFname) and the name of a
-- relation file (relFname). If the generator and relation files parse correctly, then an
-- internal representation of the generators is printed to handle. Otherwise, a parsing
-- error is printed to handle with the file name and line number.
checkRelations :: Handle -> String -> String -> IO ()
checkRelations hdl genFname relFname = do
    res <- doFilesExist [genFname, relFname]
    case res of
        Just name -> putStr ("File does not exist: " ++ name ++ "\n")
        Nothing   -> checkRelationsImpl hdl genFname relFname
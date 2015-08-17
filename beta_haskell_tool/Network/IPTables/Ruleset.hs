module Network.IPTables.Ruleset where

import           Data.List (intercalate)
import           Data.Map (Map)
import qualified Data.Map as M
import qualified Debug.Trace


import qualified Network.IPTables.Generated as Isabelle

instance Show Isabelle.Nat where
    show (Isabelle.Nat n) = "Nat " ++ show n

instance Show Isabelle.Common_primitive where
    show = Isabelle.common_primitive_toString

instance Show Isabelle.Action where
    show = Isabelle.action_toString
    
instance Show Isabelle.Simple_rule where
    show = Isabelle.simple_rule_toString

instance Show a => Show (Isabelle.Match_expr a) where
    --show = Isabelle.common_primitive_match_expr_toString -- TODO if we could fix the type, we could reuse this
    show (Isabelle.MatchAny) = ""
    show (Isabelle.Match a) = show a
    show (Isabelle.MatchNot (Isabelle.Match a)) = "! " ++ show a
    show (Isabelle.MatchNot m) = "! (" ++ show m ++ ")"
    show (Isabelle.MatchAnd m1 m2) = show m1 ++ " " ++ show m2

instance Show a => Show (Isabelle.Rule a) where
    show (Isabelle.Rule m a) = "(" ++ show m ++ ", " ++ show a ++ ")"


data Ruleset = Ruleset { rsetTables :: Map TableName Table } -- deriving (Ord)

data Table = Table { tblChains :: Map ChainName Chain} --deriving (Ord)

data Chain = Chain { chnDefault :: Maybe Isabelle.Action
                   , chnCounter :: (Integer,Integer)
                   , chnRules   :: [ParseRule]
                   }
    --deriving (Show)



data ParsedMatchAction = ParsedMatch Isabelle.Common_primitive
                       | ParsedNegatedMatch Isabelle.Common_primitive
                       | ParsedAction Isabelle.Action
    deriving (Show)

data ParseRule  = ParseRule  { ruleArgs   :: [ParsedMatchAction] } deriving (Show)



type TableName = String
type ChainName = String



mkRuleset       = Ruleset M.empty
mkTable         = Table M.empty
mkChain def ctr = Chain def ctr []
mkParseRule     = ParseRule


rsetTablesM f rset = rset { rsetTables = f (rsetTables rset) }
tblChainsM  f tbl  = tbl  { tblChains  = f (tblChains  tbl ) }
chnDefaultM f chn  = chn  { chnDefault = f (chnDefault chn ) }
chnRulesM   f chn  = chn  { chnRules   = f (chnRules   chn ) }
ruleArgsM   f rule = rule { ruleArgs   = f (ruleArgs   rule) }

atMap key f = M.adjust f key
atAL key f = map (\(k,v) -> (k,if k == key then f v else v))


example = Ruleset $ M.fromList
    [ ("filter", Table $ M.fromList [("INPUT",Chain (Just Isabelle.Drop) (0,0) [])])
    ]


-- converts a parsed table (e.g. "filter" or "raw") to the type the Isabelle code needs
-- also returns a Map with the default policies
-- may throw an error
rulesetLookup :: TableName -> Ruleset ->
    ([(String, [Isabelle.Rule Isabelle.Common_primitive])], Map ChainName Isabelle.Action)
rulesetLookup table r = case M.lookup table (rsetTables r)
    of Nothing -> error $ "Table with name `"++table++"' not found"
       Just t -> (to_Isabelle_ruleset_AssocList t, default_policies t)
    where default_policies t = M.foldWithKey (\ k v acc -> update_action k v acc) M.empty (tblChains t)
          update_action :: ChainName -> Chain -> Map ChainName Isabelle.Action -> Map ChainName Isabelle.Action
          update_action k v acc = case chnDefault v of Just a -> M.insert k a acc
                                                       Nothing -> acc


-- transforming to Isabelle type

to_Isabelle_ruleset_AssocList :: Table -> [(String, [Isabelle.Rule Isabelle.Common_primitive])]
to_Isabelle_ruleset_AssocList t = let rs = convertRuleset (tblChains t) in 
                                        if not (Isabelle.sanity_wf_ruleset rs)
                                        then error $ "Reading ruleset failed! sanity_wf_ruleset check failed."
                                        else Debug.Trace.trace "sanity_wf_ruleset passed" rs
    where convertRules = map to_Isabelle_Rule
          convertRuleset = map (\(k,v) -> (k, convertRules (chnRules v))) . M.toList 
           

to_Isabelle_Rule :: ParseRule -> Isabelle.Rule Isabelle.Common_primitive
to_Isabelle_Rule r = Isabelle.Rule
    (Isabelle.alist_and $ Isabelle.compress_parsed_extra (filter_Isabelle_Common_Primitive (ruleArgs r)))
    (filter_Isabelle_Action (ruleArgs r))

filter_Isabelle_Common_Primitive :: [ParsedMatchAction] -> [Isabelle.Negation_type Isabelle.Common_primitive]
filter_Isabelle_Common_Primitive [] = []
filter_Isabelle_Common_Primitive (ParsedMatch a : ss) = Isabelle.Pos a : filter_Isabelle_Common_Primitive ss
filter_Isabelle_Common_Primitive (ParsedNegatedMatch a : ss) = Isabelle.Neg a : filter_Isabelle_Common_Primitive ss
filter_Isabelle_Common_Primitive (ParsedAction _ : ss) = filter_Isabelle_Common_Primitive ss

filter_Isabelle_Action :: [ParsedMatchAction] -> Isabelle.Action
filter_Isabelle_Action ps = case fAction ps of [] -> Isabelle.Empty
                                               [a] -> a
                                               as -> error $ "at most one action per rule: " ++ show as
    where fAction [] = []
          fAction (ParsedMatch _ : ss) = fAction ss
          fAction (ParsedNegatedMatch _ : ss) = fAction ss
          fAction (ParsedAction a : ss) = a : fAction ss


-- toString functions

instance Show Ruleset where
    show rset =
        let tables = map renderTable $ M.toList $ rsetTables rset
        in  join tables


renderTable :: (TableName, Table) -> String
renderTable (name,tbl) = join
    [ "*"++name
    , declareChains (tblChains tbl)
    , addRules (tblChains tbl)
    , "COMMIT"
    ]

declareChains :: Map ChainName Chain -> String
declareChains chnMap =
    join $ map renderDecl (M.toList chnMap)
    where renderDecl (name, chain) =
            let (packets,bytes) = chnCounter chain
            in  concat [ ":", name, " ", renderPolicy (chnDefault chain)
                       , " [", show packets, ":", show bytes, "]"
                       ]

addRules :: Map ChainName Chain -> String
addRules chnMap =
    let rules = concatMap expandChain (M.toList chnMap)
        expandChain (name,chain) = map (\rl -> (name,rl)) $ chnRules chain
        renderRule (chnname, rl) =
            concat ["-A ", chnname
                   , concatMap expandOpt (ruleArgs rl)
                   ]
        expandOpt opt = concat [" `", show opt, "'"]
    in  join $ map renderRule rules


renderPolicy (Just Isabelle.Accept)      = "ACCEPT"
renderPolicy (Just Isabelle.Drop)        = "DROP"
renderPolicy Nothing = "-"


join = intercalate "\n"

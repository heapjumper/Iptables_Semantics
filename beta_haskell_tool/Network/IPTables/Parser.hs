{-# LANGUAGE NoMonomorphismRestriction #-}
module Network.IPTables.Parser
( parseIptablesSave
) where

import Control.Applicative ((<$>),(<*>),(<*),(*>))
import Data.List (isPrefixOf)

import qualified Data.Map as M
import qualified Control.Monad (when)
import qualified Debug.Trace


import Text.Parsec hiding (token)

import Network.IPTables.Ruleset

import qualified Network.IPTables.Generated as Isabelle


data RState = RState { rstRules  :: Ruleset
                     , rstActive :: Maybe TableName
                     }
    deriving (Show)

parseIptablesSave :: SourceName -> String -> Either ParseError Ruleset
parseIptablesSave = runParser ruleset initRState

initRState = RState mkRuleset Nothing

rstRulesM :: (Ruleset -> Ruleset) -> RState -> RState
rstRulesM  f rst = rst { rstRules  = f (rstRules  rst) }

rstActiveM :: (Maybe TableName -> Maybe TableName) -> RState -> RState
rstActiveM f rst = rst { rstActive = f (rstActive rst) }


ruleset :: Parsec String RState Ruleset
ruleset = do
    many $ choice [table, chain, rule, commit, comment, emptyLine]
    eof
    rstRules <$> getState


comment = line $ do
    char '#' >> skipWS >> restOfLine
    return ()

emptyLine = line (return ())

table = line $ do
    lit "*"
    name <- tableName

    -- table with same name will replace existing table
    modifyState $ (rstRulesM . rsetTablesM) (M.insert name mkTable)
                . rstActiveM (const $ Just name)
    return ()

chain = line $ do
    lit ":"
    name   <- chainName <* skipWS
    defPol <- policy
    ctr    <- counter
    _      <- restOfLine

    let chn = mkChain defPol ctr
    tblname <- getTableName
    modifyState $ (rstRulesM . rsetTablesM . atMap tblname . tblChainsM)
                    (M.insert name chn)

    return ()

probablyNegated parser = ParsedNegatedMatch <$> try (lit "! " >> (lookAheadEOT parser) <* skipWS)
                     <|> ParsedMatch <$> (try (lookAheadEOT parser) <* skipWS)
                     
notNegated parser = ParsedMatch <$> (try (lookAheadEOT parser) <* skipWS)
    

knownMatch = do
    p <-  (probablyNegated $ lit "-p " >> Isabelle.Prot <$> protocol)
    
      <|> (probablyNegated $ lit "-s " >> Isabelle.Src <$> ipv4addrOrCidr)
      -- TODO: negation syntax
      <|> (notNegated $ lit "-m iprange --src-range " >> Isabelle.Src <$> ipv4range)
      <|> (probablyNegated $ lit "-d " >> Isabelle.Dst <$> ipv4addrOrCidr)
      <|> (notNegated $ lit "-m iprange --dst-range " >> Isabelle.Dst <$> ipv4range)
      
      <|> (probablyNegated $ lit "-m tcp --sport "
                             >> Isabelle.Src_Ports <$> (\p -> [p]) <$> parsePortOne)
      <|> (probablyNegated $ lit "-m udp --sport "
                             >> Isabelle.Src_Ports <$> (\p -> [p]) <$> parsePortOne)
      -- TODO: negation syntax?
      <|> (probablyNegated $ lit "-m multiport --sports "
                             >> Isabelle.Src_Ports <$> parseCommaSeparatedList parsePortOne)
      <|> (probablyNegated $ lit "-m tcp --dport "
                             >> Isabelle.Dst_Ports <$> (\p -> [p]) <$> parsePortOne)
      <|> (probablyNegated $ lit "-m udp --dport "
                             >> Isabelle.Dst_Ports <$> (\p -> [p]) <$> parsePortOne)
      <|> (probablyNegated $ lit "-m multiport --dports "
                             >> Isabelle.Dst_Ports <$> parseCommaSeparatedList parsePortOne)
      
      <|> (probablyNegated $ lit "-i " >> Isabelle.IIface <$> iface)
      <|> (probablyNegated $ lit "-o " >> Isabelle.OIface <$> iface)
      
      -- TODO: can ctstate be negated? never seen or tested this
      <|> (probablyNegated $ lit "-m state --state " >> Isabelle.CT_State <$> ctstate)
      <|> (probablyNegated $ lit "-m conntrack --ctstate " >> Isabelle.CT_State <$> ctstate)
      
      
      <|> ((lookAheadEOT target) <* skipWS)
      
    return $ p
    
unknownMatch = token "unknown match" $ do
    extra <- (many1 (noneOf " \t\n\"") <|> try quotedString)
    let e = if "-j" `isPrefixOf` extra
              then Debug.Trace.trace ("Warning: probably a parse error at "++extra) extra
              else extra
    return $ ParsedMatch $ Isabelle.Extra $ e
    where quotedString = do
              a <- string "\""
              b <- many (noneOf "\"\n")
              c <- string "\""
              return (a++b++c)

rule = line $ do
    lit "-A"
    chnname <- chainName <* skipWS
    args    <- many (knownMatch <|> unknownMatch)
    unparsed <- restOfLine

    let rest    = if unparsed == ""
                  then []
                  else Debug.Trace.trace ("ERROR unparsable : " ++ unparsed)
                       [ParsedMatch (Isabelle.Extra unparsed)]
        myArgs  = args ++ rest
        rl      = mkParseRule myArgs

    tblname <- getTableName
    modifyState $ (  rstRulesM
                   . rsetTablesM . atMap tblname
                   . tblChainsM  . atMap chnname
                   . chnRulesM)
                  (++ [rl])

    return ()

commit = line $ do
    lit "COMMIT"
    restOfLine

    modifyState $ rstActiveM (const Nothing)

    return ()


getTableName = getState >>=
    safeJust "No active table." return . rstActive

safeJust msg f = maybe (fail msg) f


tableName = token "table name" $ many1 $ oneOf $ ['A'..'Z']++['a'..'z']
chainName = many1 $ oneOf $ ['A'..'Z']++['a'..'z']++['0'..'9']++['_','-','~']

policy  =  token "policy"
        $  (string "ACCEPT" >> return (Just Isabelle.Accept))
       <|> (string "DROP"   >> return (Just Isabelle.Drop))
       <|> (string "-"      >> return Nothing)

counter = token "counter" $ do
    char '['
    packets <- nat
    char ':'
    bytes <- nat
    char ']'
    return (packets,bytes)


-- Parsing Helper --

-- cannot be combined with lookAheadEOT
lit str = token str (string str)

restOfLine = many (noneOf "\n")

line  p      = p <* (skipWS >> eol)
token desc p = (p <* skipWS) <?> desc
skipWS = many $ oneOf ws

eol = char '\n'
ws  = " \t"

-- loook ahead end of token
-- cannot be combined with token
lookAheadEOT parser = do 
    res <- parser
    lookAhead (oneOf ws <|> eol)
    return res

nat = do
    n <- (read :: String -> Integer) <$> many1 (oneOf ['0'..'9']) -- ['0'..'9']++['-']
    if n < 0
        then error ("nat `"++ show n ++ "' must be geq zero")
        else return n


parseCommaSeparatedList parser = sepBy parser (char ',')

-- Parsing Isabelle primitives --
natMaxval maxval = do
    n <- nat
    if n > maxval
        then error ("nat `"++ show n ++ "' must be smaller than " ++ show maxval)
        else return (Isabelle.Nat n)

ipv4dotdecimal = do
    a <- natMaxval 255
    char '.'
    b <- natMaxval 255
    char '.'
    c <- natMaxval 255
    char '.'
    d <- natMaxval 255
    return (a,(b,(c,d)))


ipv4addr = do
    ip <- ipv4dotdecimal
    return (Isabelle.Ip4Addr ip)

ipv4cidr = do
    ip <- ipv4dotdecimal
    char '/'
    netmask <- natMaxval 32
    return (Isabelle.Ip4AddrNetmask ip netmask)

ipv4addrOrCidr = try ipv4cidr <|> try ipv4addr

ipv4range = do
    ip1 <- ipv4dotdecimal
    char '-'
    ip2 <- ipv4dotdecimal
    return (Isabelle.Ip4AddrRange ip1 ip2)
    
protocol = Isabelle.Proto <$> choice [string "tcp" >> return Isabelle.TCP
                                     ,string "udp" >> return Isabelle.UDP
                                     ,string "icmp" >> return Isabelle.ICMP
                                     ]

iface = Isabelle.Iface <$> many1 (oneOf $ ['A'..'Z']++['a'..'z']++['0'..'9']++['+','*','.'])

parsePortOne = try tuple <|> single
    where port_raw = Isabelle.nat_to_16word <$> natMaxval 65535
          single = do
              p <- port_raw
              return (p,p)
          tuple = do
              p1 <- port_raw
              char ':'
              p2 <- port_raw
              if p2 `Isabelle.word_less_eq` p1 then
                  return (Debug.Trace.trace (concat
                             ["WARNING: port "
                             ,show (Isabelle.word_to_nat p1)
                             ," >= " ++ show (Isabelle.word_to_nat p2)
                             ])
                         (p1,p2))
                  else return (p1,p2)


ctstate = Isabelle.mk_Set <$> parseCommaSeparatedList ctstateOne
    where ctstateOne = choice [string "NEW" >> return Isabelle.CT_New
                              ,string "ESTABLISHED" >> return Isabelle.CT_Established
                              ,string "RELATED" >> return Isabelle.CT_Related
                              ,string "UNTRACKED" >> return Isabelle.CT_Untracked]              


-- needs LookAheadEOT, otherwise, this might happen to the custom LOG_DROP target:
-- -A ranges_96 `ParsedAction -j LOG' `ParsedMatch ~~_DROP~~'
target = ParsedAction <$> (
           try (string "-j REJECT --reject-with "
                >> many1 (oneOf $ ['a'..'z']++['-']) >> return (Isabelle.Reject))
       <|> try (string "-g " >> Isabelle.Goto <$> lookAheadEOT chainName)
       <|> try (string "-j " >> choice (map (try. lookAheadEOT)
                                       [string "DROP" >> return Isabelle.Drop
                                       ,string "REJECT" >> return Isabelle.Reject
                                       ,string "ACCEPT" >> return Isabelle.Accept
                                       ,string "LOG" >> return Isabelle.Log
                                       ,string "RETURN" >> return Isabelle.Return
                                       ]))
       <|> try (string "-j " >> Isabelle.Call <$> lookAheadEOT chainName)
       )
       
    
-- Helper --
atMap key f = M.adjust f key

trim s = let rm = dropWhile (`elem` " \t")
         in  rm $ reverse $ rm $ reverse s

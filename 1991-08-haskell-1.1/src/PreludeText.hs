module	PreludeText (
	Text(readsPrec,showsPrec,readList,showList),
	ReadS, ShowS, reads, shows, show, read, lex,
	showChar, showString, readParen, showParen ) where

type  ReadS a = String -> [(a,String)]
type  ShowS   = String -> String

class  Text a  where
    readsPrec :: Int -> ReadS a
    showsPrec :: Int -> a -> ShowS
    readList  :: ReadS [a]
    showList  :: [a] -> ShowS

    readList    = readParen False (\r -> [pr | ("[",s)	<- lex r,
					       pr	<- readl s])
	          where readl  s = [([],t)   | ("]",t)  <- lex s] ++
				   [(x:xs,u) | (x,t)    <- reads s,
					       (xs,u)   <- readl' t]
			readl' s = [([],t)   | ("]",t)  <- lex s] ++
			           [(x:xs,v) | (",",t)  <- lex s,
					       (x,u)	<- read t,
					       (xs,v)   <- readl' u]
    showList []	= showString "[]"
    showList (x:xs)
		= showChar '[' . shows x . showl xs
		  where showl []     = showChar ']'
			showl (x:xs) = showChar ',' . shows x . showl xs

reads 	        :: (Text a) => ReadS a
reads		=  readsPrec 0

shows 	    	:: (Text a) => a -> ShowS
shows		=  showsPrec 0

read 	    	:: (Text a) => String -> a
read s 	    	=  case [x | (x,t) <- reads s, ("","") <- lex t] of
			[x] -> x
			[]  -> error "read{PreludeText}: no parse"
			_   -> error "read{PreludeText}: ambiguous parse"

show 	    	:: (Text a) => a -> String
show x 	    	=  shows x ""

showChar    	:: Char -> ShowS
showChar    	=  (:)

showString  	:: String -> ShowS
showString  	=  (++)

showParen   	:: Bool -> ShowS -> ShowS
showParen b p 	=  if b then showChar '(' . p . showChar ')' else p

readParen   	:: Bool -> ReadS a -> ReadS a
readParen b g	=  if b then mandatory else optional
		   where optional r  = g r ++ mandatory r
			 mandatory r = [(x,u) | ("(",s) <- lex r,
						(x,t)   <- optional s,
						(")",u) <- lex t    ]

lex 	    		:: ReadS String
lex ""			= [("","")]
lex (c:s) | isSpace c	= lex (dropWhile isSpace s)
lex ('-':'-':s)		= case dropWhile (/= '\n') s of
				 '\n':t -> lex t
				 _	-> [] -- unterminated end-of-line
					      -- comment

lex ('{':'-':s)		= lexNest lex s
			  where
			  lexNest f ('-':'}':s) = f s
			  lexNest f ('{':'-':s) = lexNest (lexNest f) s
			  lexNest f (c:s)	      = lexNest f s
			  lexNest _ ""		= [] -- unterminated
						     -- nested comment

lex ('-':'>':s)		= [("->",s)]
lex ('<':'-':s)		= [("<-",s)]
lex ('\'':s)		= [('\'':ch++"'", t) | (ch,t)  <- lexLitChar s,
					       ch /= "'"		]
lex ('"':s)		= [('"':str, t)      | (str,t) <- lexString s]
			  where
			  lexString ('"':s) = [("\"",s)]
			  lexString s = [(ch++str, u)
						| (ch,t)  <- lexStrItem s,
						  (str,u) <- lexString t  ]

			  lexStrItem ('\\':'&':s) = [("\\&",s)]
			  lexStrItem ('\\':c:s) | isSpace c
			      = [("\\&",t) | '\\':t <- [dropWhile isSpace s]]
			  lexStrItem s		  = lexLitChar s

lex (c:s) | isSingle c	= [([c],s)]
	  | isSym1 c	= [(c:sym,t)	     | (sym,t) <- [span isSym s]]
	  | isAlpha c	= [(c:nam,t)	     | (nam,t) <- [span isIdChar s]]
	  | isDigit c	= [(c:ds++fe,t)	     | (ds,s)  <- [span isDigit s],
					       (fe,t)  <- lexFracExp s	   ]
	  | otherwise	= []	-- bad character
		where
		isSingle c  =  c `elem` ",;()[]{}_"
		isSym1 c    =  c `elem` "-~" || isSym c
		isSym c	    =  c `elem` "!@#$%&*+./<=>?\\^|:"
		isIdChar c  =  isAlphanum c || c `elem` "_'"

		lexFracExp ('.':s) = [('.':ds++e,u) | (ds,t) <- lexDigits s,
						      (e,u)  <- lexExp t    ]
		lexFracExp s	   = [("",s)]

		lexExp (e:s) | e `elem` "eE"
			 = [(e:c:ds,u) | (c:t)	<- [s], c `elem` "+-",
						   (ds,u) <- lexDigits t] ++
			   [(e:ds,t)   | (ds,t)	<- lexDigits s]
		lexExp s = [("",s)]

lexDigits		:: ReadS String	
lexDigits		=  nonnull isDigit

nonnull			:: (char -> Bool) -> ReadS String
nonnull p s		=  [(cs,t) | (cs@(_:_),t) <- [span p s]]

lexLitChar		:: ReadS String
lexLitChar ('\\':s)	=  [('\\':esc, t) | (esc,t) <- lexEsc s]
	where
	lexEsc (c:s)	 | c `elem` "abfnrtv\\\"'" = [([c],s)]
	lexEsc ('^':c:s) | c >= '@' && c <= '_'  = [(['^',c],s)]
	lexEsc s@(d:_)	 | isDigit d		 = lexDigits s
	lexEsc ('o':s)	=  [('o':os, t) | (os,t) <- nonnull isOctDigit s]
	lexEsc ('x':s)	=  [('x':xs, t) | (xs,t) <- nonnull isHexDigit s]
	lexEsc s@(c:_)	 | isUpper c
			=  case [(mne,s') | mne <- "DEL" : elems asciiTab,
					    ([],s') <- [match mne s]	  ]
			   of (pr:_) -> [pr]
			      []     -> []
	lexEsc _	=  []
lexLitChar (c:s)	=  [([c],s)]

isOctDigit c  =  c >= '0' && c <= '7'
isHexDigit c  =  isDigit c || c >= 'A' && c <= 'F'
			   || c >= 'a' && c <= 'f'

match			:: (Eq a) => [a] -> [a] -> ([a],[a])
match (x:xs) (y:ys) | x == y  =  match xs ys
match xs     ys		      =  (xs,ys)

asciiTab = listArray ('\NUL', ' ')
	   ["NUL", "SOH", "STX", "ETX", "EOT", "ENQ", "ACK", "BEL",
	    "BS",  "HT",  "LF",  "VT",  "FF",  "CR",  "SO",  "SI", 
	    "DLE", "DC1", "DC2", "DC3", "DC4", "NAK", "SYN", "ETB",
	    "CAN", "EM",  "SUB", "ESC", "FS",  "GS",  "RS",  "US", 
	    "SP"] 


-- Trivial type

instance  Text ()  where
    readsPrec p    = readParen False
    	    	    	    (\r -> [((),t) | ("(",s) <- lex r,
					     (")",t) <- lex s ] )
    showsPrec p () = showString "()"


-- Binary type

instance  Text Bin  where
    readsPrec p s  =  error "readsPrec{PreludeText}: Cannot read Bin."
    showsPrec p b  =  showString "<<Bin>>"


-- Character type

instance  Text Char  where
    readsPrec p      = readParen False
    	    	    	    (\r -> [(c,t) | ('\'':s,t)<- lex r,
					    (c,_)     <- readLitChar s])

    showsPrec p '\'' = showString "'\\''"
    showsPrec p c    = showChar '\'' . showLitChar c . showChar '\''

    readList = readParen False (\r -> [pr | ('"':s, t) <- lex r,
					    pr <- readl s	])
	       where readl ('"':s)	= [("",s)]
		     readl ('\\':'&':s)	= readl s
		     readl s		= [(c:cs,u) | (c ,t) <- readLitChar s,
						      (cs,u) <- readl t	      ]

    showList cs = showChar '"' . showl cs
		 where showl ""       = showChar '"'
		       showl ('"':cs) = showString "\\\"" . showl cs
		       showl (c:cs)   = showLitChar c . showl cs

readLitChar 		:: ReadS Char
readLitChar ('\\':s)	=  readEsc s
	where
	readEsc ('a':s)	 = [('\a',s)]
	readEsc ('b':s)	 = [('\b',s)]
	readEsc ('f':s)	 = [('\f',s)]
	readEsc ('n':s)	 = [('\n',s)]
	readEsc ('r':s)	 = [('\r',s)]
	readEsc ('t':s)	 = [('\t',s)]
	readEsc ('v':s)	 = [('\v',s)]
	readEsc ('\\':s) = [('\\',s)]
	readEsc ('"':s)	 = [('"',s)]
	readEsc ('\'':s) = [('\'',s)]
	readEsc ('^':c:s) | c >= '@' && c <= '_'
			 = [(chr (ord c - ord '@'), s)]
	readEsc s@(d:_) | isDigit d
			 = [(chr n, t) | (n,t) <- readDec s]
	readEsc ('o':s)  = [(chr n, t) | (n,t) <- readOct s]
	readEsc ('x':s)	 = [(chr n, t) | (n,t) <- readHex s]
	readEsc s@(c:_) | isUpper c
			 = let table = ('\DEL' := "DEL") : assocs asciiTab
			   in case [(c,s') | (c := mne) <- table,
					     ([],s') <- [match mne s]]
			      of (pr:_) -> [pr]
				 []	-> []
	readEsc _	 = []
readLitChar (c:s)	=  [(c,s)]

showLitChar 		   :: Char -> ShowS
showLitChar c | c > '\DEL' =  protectEsc isDigit (showInt (ord c))
showLitChar '\DEL'	   =  showString "\\DEL"
showLitChar '\\'	   =  showString "\\\\"
showLitChar c | c >= ' '   =  showChar c
showLitChar '\a'	   =  showString "\\a"
showLitChar '\b'	   =  showString "\\b"
showLitChar '\f'	   =  showString "\\f"
showLitChar '\n'	   =  showString "\\n"
showLitChar '\r'	   =  showString "\\r"
showLitChar '\t'	   =  showString "\\t"
showLitChar '\v'	   =  showString "\\v"
showLitChar '\SO'	   =  protectEsc (== 'H') (showString "\\SO")
showLitChar c		   =  showString ('\\' : asciiTab!c)

protectEsc p f		   = f . cont
			     where cont s@(c:_) | p c = "\\&" ++ s
				   cont s	      = s

readDec, readOct, readHex :: (Integral a) => ReadS a
readDec = readInt 10 isDigit (\d -> ord d - ord '0')
readOct = readInt  8 isOctDigit (\d -> ord d - ord '0')
readHex = readInt 16 isHexDigit hex
	    where hex d = ord d - (if isDigit d then ord '0'
				   else ord (if isUpper d then 'A' else 'a')
					- 10)

readInt :: (Integral a) => a -> (Char -> Bool) -> (Char -> Int) -> ReadS a
readInt radix isDig digToInt s =
    [(foldl1 (\n d -> n * radix + d) (map (fromIntegral . digToInt) ds), r)
	| (ds,r) <- nonnull isDig s ]

showInt	:: (Integral a) => a -> ShowS
showInt n = if n < 0 then showChar '-' . showInt' (-n) else showInt' n
	    where showInt' n r = let (n',d) = divRem n 10
				     r' = chr (ord '0' + fromIntegral d) : r
				 in if n' == 0 then r' else showInt n' r'

-- Standard integral types

instance  Text Int  where
    readsPrec p = readSigned readDec
    showsPrec   = showSigned showInt

instance  Text Integer  where
    readsPrec p = readSigned readDec
    showsPrec   = showSigned showInt

readSigned:: (Real a) => ReadS a -> ReadS a
readSigned readPos = readParen False read'
		     where read' r  = read'' r ++
				      [(-x,t) | ("-",s) <- lex r,
						(x,t)   <- read'' s]
			   read'' r = [(n,s)  | (str,s) <- lex r,
		      				(n,"")  <- readPos str]

showSigned:: (Real a) => (a -> ShowS) -> Int -> a -> ShowS
showSigned showPos p x = showParen (x < 0 && p > 6) (showPos x)
		 


-- Standard real floating-point types

instance  Text Float  where
    readsPrec p = readSigned readFloat
    showsPrec   = showSigned showFloat

instance  Text Double  where
    readsPrec p = readSigned readFloat
    showsPrec   = showSigned showFloat

-- The functions readFloat and showFloat below use rational arithmetic
-- to insure correct conversion between the floating-point radix and
-- decimal.  It is often possible to use a higher-precision floating-
-- point type to obtain the same results.

readFloat r = [(fromRational ((n%1)*10^^(k-d)), t) | (n,d,s) <- readFix r,
						     (k,t)   <- readExp s]
              where readFix r = [(read (ds++ds'), length ds', t)
					| (ds,'.':s) <- lexDigits r,
					  (ds',t)    <- lexDigits s ]

		    readExp (e:s) | e `elem` "eE" = readExp' s
                    readExp s			  = [(0,s)]

                    readExp' ('-':s) = [(-k,t) | (k,t) <- readDec s]
                    readExp' ('+':s) = readDec s
                    readExp' s	     = readDec s

-- The number of decimal digits m below is chosen to guarantee 
-- read(show x) = x.  See
--	Matula, D. W.  A formalization of floating-point numeric base
--	conversion.  IEEE Transactions on Computers C-19, 8 (1970 August),
--	681-692.
 
showFloat x =
    if x == 0 then showString ("0." ++ take (m-1) (repeat '0'))
	      else if e >= m-1 || e < 0 then showSci else showFix
    where
    showFix	= showString whole . showChar '.' . showString frac
		  where (whole,frac) = splitAt (e+1) (show sig)
    showSci	= showChar d . showChar '.' . showString frac
		      . showChar 'e' . showInt e
    		  where (d:frac) = show sig
    (m, sig, e) = if b == 10 then (w,  	s,   n+w-1)
		  	     else (m', sig', e'   )
    m'		= ceiling ((fromInt w * log (fromInteger b))/log 10) + 1
    (sig', e')	= if	  sig1 >= 10^m'     then (round (t/10), e1+1)
		  else if sig1 <  10^(m'-1) then (round (t*10), e1-1)
		  			    else (sig1,		e1  )
    sig1	= round t
    t		= s%1 * (b%1)^^n * 10^^(m'-e1-1)
    e1		= floor (logBase 10 x)
    (s, n)	= decodeFloat x
    b		= floatRadix x
    w		= floatDigits x


-- Lists

instance  (Text a) => Text [a]  where
    readsPrec p = readList
    showsPrec p = showList


-- Tuples

instance  (Text a, Text b) => Text (a,b)  where
    readsPrec p = readParen False
    	    	    	    (\r -> [((x,y), w) | ("(",s) <- lex r,
						 (x,t)   <- reads s,
						 (",",u) <- lex t,
						 (y,v)   <- reads u,
						 (")",w) <- lex v ] )

    showsPrec p (x,y) = showChar '(' . shows x . showChar ',' .
    	    	    	    	       shows y . showChar ')'
-- et cetera


-- Functions

instance  Text (a -> b)  where
    readsPrec p s  =  error "readsPrec{PreludeText}: Cannot read functions."
    showsPrec p f  =  showString "<<function>>"

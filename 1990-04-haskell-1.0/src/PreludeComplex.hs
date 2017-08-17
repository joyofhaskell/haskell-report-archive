-- Complex Numbers

module PreludeComplex ( Complex(:+) )  where

infix  6  :+

data  (RealFloat a)     => Complex a = a :+ a  deriving (Eq,Binary,Text)

instance  (RealFloat a) => Num (Complex a)  where
    (x:+y) + (x':+y')	=  (x+x') :+ (y+y')
    (x:+y) - (x':+y')	=  (x-x') :+ (y-y')
    (x:+y) * (x':+y')	=  (x*x'-y*y') :+ (x*y'+y*x')
    negate (x:+y)	=  negate x :+ negate y
    abs z		=  magnitude z :+ 0
    signum 0		=  0
    signum z@(x:+y)	=  x/r :+ y/r  where r = magnitude z
    fromInteger n	=  fromInteger n :+ 0

instance  (RealFloat a) => Fractional (Complex a)  where
    (x:+y) / (x':+y')	=  (x*x''+y*y'') / d :+ (y*x''-x*y'') / d
			   where x'' = scaleFloat k x'
				 y'' = scaleFloat k y'
				 k   = - (max (exponent x') (exponent y'))
				 d   = x'*x'' + y'*y''

    fromRational a	=  fromRational a :+ 0

instance  (RealFloat a) => Floating (Complex a)	where
    pi             =  pi :+ 0
    exp (x:+y)     =  expx * cos y :+ expx * sin y
                      where expx = exp x
    log z          =  log (magnitude z) :+ phase z

    sqrt 0         =  0
    sqrt z@(x:+y)  =  u :+ (if y < 0 then -v else v)
                      where (u,v) = if x < 0 then (v',u') else (u',v')
                            v'    = abs y / (u'*2)
                            u'    = sqrt ((magnitude z + abs x) / 2)

    sin (x:+y)     =  sin x * cosh y :+ cos x * sinh y
    cos (x:+y)     =  cos x * cosh y :+ sin x * sinh y
    tan (x:+y)     =  (sinx*coshy:+cosx*sinhy)/(cosx*coshy:+sinx*sinhy)
                      where sinx  = sin x
                            cosx  = cos x
                            sinhy = sinh y
                            coshy = cosh y

    sinh (x:+y)    =  cos y * sinh x :+ sin  y * cosh x
    cosh (x:+y)    =  cos y * cosh x :+ (- (sin y) * sinh x)
    tanh (x:+y)    =  (cosy*sinhx:+siny*coshx)/(cosy*coshx:+(-siny*sinhx))
                      where siny  = sin y
                            cosy  = cos y
                            sinhx = sinh x
                            coshx = cosh x

    asin z@(x:+y)  =  y':+(-x')
                      where  (x':+y') = log ((-y:+x) + sqrt (1 - z*z))
    acos z@(x:+y)  =  y'':+(-x'')
                      where (x'':+y'') = log (z + ((-y'):+x'))
                            (x':+y')   = sqrt (1 - z*z)
    atan z@(x:+y)  =  y':+(-x')
                      where
                      (x':+y') = log (((-y+1):+x) * sqrt (1/(1+z*z)))

    asinh z        =  log (z + sqrt (1+z*z))
    acosh z        =  log (z + (z+1) * sqrt ((z-1)/(z+1)))
    atanh z        =  log ((z+1) * sqrt (1 - 1/(z*z)))
! Copyright (C) 2009 Your name.
! See http://factorcode.org/license.txt for BSD license.
USING: kernel accessors math locals math.functions io bit-arrays sequences namespaces arrays math.bitwise prettyprint math.constants io.encodings.binary io.servers.connection io.binary io.sockets calendar threads fry ;
IN: arm


! TODO: calibration et exception quand valeurs interdites

TUPLE: point x y ;

: <point> ( -- point ) point new ;

: l1 ( -- longueur ) 22 ;
: l2 ( -- longueur ) 15 ;
: shoulder-max ( -- val ) 15 ;
: shoulder-min    ( -- val ) 160 ; 
: elbow-max ( -- val ) -20 ;
: elbow-min    ( -- val ) -156 ; 

:: check-shoulder-angle ( shoulder -- bool )
   shoulder shoulder-max >=
   shoulder shoulder-min <=
   and ;

:: check-elbow-angle ( elbow -- bool )
   elbow elbow-max <=
   elbow elbow-min >=
   and ;

:: check-angles ( shoulder elbow -- bool )
   shoulder check-shoulder-angle
   elbow check-elbow-angle
   and ;

: square ( a -- a*a ) dup * ;
: N ( point -- resultat ) 
    [
    [ x>> ] [ y>> ] bi [ square ] bi@ + 
    l2 square l1 square -
    +
    ] keep
    y>> 2 * / ;

: A ( point -- resultat )
    [ x>> ] [ y>> ] bi / square 1 + ;

:: B ( point -- resultat ) 
    0 point [ x>> ] [ y>> ] bi / point N 2 * * - ;


: C ( point -- resultat )
    [ [ x>> ] [ y>> ] bi [ square ] bi@ ] keep
    [ N square ] keep
    [ y>> ] [ N ] bi 2 * *
    l1 square
    + - + + ;
    
:: delta2 ( a b c -- delta )
    b square 4 a c * * - ;

: delta ( a b c -- delta )
    delta2 sqrt ;


:: eq-solve ( a b c -- solution1 solution2 )
    0 b -
    a b c delta
    [ + ] [ - ] 2bi 
    [ 2 a * / ] bi@ ;

: y-from-x ( x point -- y )
    [ N ] keep
    [ x>> ] [ y>> ] bi / [ swap ] dip * - ;
  

: squared-lenght ( point point -- length )
    [ [ x>> ] bi@ - square ] 2keep
    [ y>> ] bi@ - square
    + ;

SYMBOL: table
SYMBOL: tagged
: table-init ( -- ) 
    100 100 * <bit-array> table set 
    <point> 100 100 * <array> tagged set ;

: table-length ( -- length ) 100 ;

: check-bounds ( x y -- bool )
   [
   [ 0 >=  ] keep
   100 <
   ] bi@ and and and ;

: my-bounds-error? ( x y -- x y )
    [ check-bounds
    [ "ARRAY OVERFLOW!!" print ]
    unless ] 2keep ;

: to-index ( x y -- index )
      my-bounds-error?
      swap table-length * + ;

: my-nth ( x y table -- bool )
      [ to-index ] dip nth ;

: my-set-nth ( elt x y seq -- )
  [ to-index ] dip set-nth ;

: already-visited? ( x y -- bool )
    tagged get my-nth x>> ;

: tag ( px py x y -- )
    tagged get my-nth 
    swap >>y 
    swap >>x drop ;

: intersect ( point -- point1 point2 )
    [ [ A ] [ B ] [ C ] tri [ eq-solve ] [ delta2 ] 3bi ] keep swap
    0 >=
    [
        ! dup [ swap ] dip
        tuck
        [ [ dup ] dip y-from-x ] 2bi@
    ]
    [
    3drop 0 0 0 0 "Pas de solutions" print
    ]
    if [ point boa ] 2bi@ ;

! l'angle entre x et ( le point et 0,0 )
: angle-point ( pt1 -- angle )
      [ y>> ]
      [ [ y>> ] [ x>> ] bi [ square ] bi@ + sqrt ]
      [ x>> ] tri 
      + / atan 2 * ; 
      
! l'angle entre x et pt1->pt2 
: angle-vector ( pt1 pt2 -- angle )
     [ [ x>> ] bi@  - ] [ [ y>> ] bi@ - ] 2bi
     point boa angle-point ;
     
! l'angle entre le vecteur pt1->pt2 et pt3->pt4     
: angle-vectors ( pt1 pt2 pt3 pt4 -- angle )
    [ angle-vector ] 2bi@ - ;

:: intersect-angles ( pt -- a1 b1 a2 b2 )
   pt intersect 
   [ 
      [ angle-point ]
      [ pt swap dup 0 0 point boa angle-vectors ]
      bi
   ] bi@ ;

: to-degrees ( angle -- angle )
 180 * pi / ;
 : to-radians ( angle -- angle )
 pi * 180 / ;
        
: to-elbow-degrees ( angle -- angle )
 elbow-min - HEX: FF elbow-max elbow-min - / * >integer ;

: to-shoulder-degrees ( angle -- angle )
 shoulder-min - HEX: FF shoulder-max shoulder-min - / * >integer ;

: to-byte-stream ( int -- ) 
    1 >le write ;

:: serial-test ( cmd value -- )
"localhost" 54321 <inet> binary [ CHAR: s cmd value [ to-byte-stream ] tri@ CHAR: \r to-byte-stream ] with-client ;

: serial-send ( quot -- )
   [ "localhost" 54321 <inet> binary ] dip with-client ; inline

:: serial-print ( cmd value -- )
    CHAR: s cmd value [ to-byte-stream ] tri@ CHAR: \r to-byte-stream ;

:: arm-control-degrees-print ( a1 a2 -- )
   HEX: 81 a1 to-shoulder-degrees serial-print HEX: 82 a2 to-elbow-degrees serial-print ;

SYMBOL: current-angle-shoulder
SYMBOL: current-angle-elbow

: get-current-position ( -- x y )
  l2 current-angle-shoulder get to-radians 
  l1 current-angle-shoulder get current-angle-elbow get + to-radians [ cos * ] 2bi@ +
  l2 current-angle-shoulder get to-radians 
  l1 current-angle-shoulder get current-angle-elbow get + to-radians [ sin * ] 2bi@ + ;

:: arm-control-degrees ( a1 a2 -- )
   a1 a2 check-angles
   [ a1 current-angle-shoulder set
     a2 current-angle-elbow set 
     [ a1 a2 arm-control-degrees-print ] serial-send ]
   [ "Bad Angles" throw ] if ;

: arm-control-radian ( a1 a2 -- )
  [ to-degrees ] bi@ arm-control-degrees ;
   
: arm-control-position ( x y -- )
  point boa intersect-angles arm-control-radian 2drop ;



: distance-smaller-than? ( x y eps -- bool )
  '[ - abs _ < ] call ;

: arrived? ( x y -- bool )
  0.1 distance-smaller-than? ;

:: avance ( a1 a2 -- newa2 )
   a1 a2 arrived?
   [ a1 ]
   [ a1 a2 < [ a1 0.3 + ] [ a1 0.3 - ] if ] if ;

:: go-to-angles ( shoulder elbow -- )
   elbow current-angle-elbow get arrived? shoulder current-angle-shoulder get arrived? and
  [ ]
  [ "iterating" print
   current-angle-shoulder get shoulder avance
   current-angle-elbow get elbow avance 
   arm-control-degrees 10 milliseconds sleep
   shoulder elbow go-to-angles ]
  if ;

:: go-to-position ( x y -- )
  x get-current-position y [ - abs 1 < ] 2bi@ and
  [ ]
  [ "iterating" print
  get-current-position x swap y [ avance ] 2bi@
  "Wanting to go to : " print [ . . ] 2keep
  arm-control-position 1 milliseconds sleep
  x y go-to-position ]
  if ;


: demo ( -- )
18 1 go-to-position
31 1 go-to-position
31 5 go-to-position
36 5 go-to-position
36 1 go-to-position
25 1 go-to-position
25 5 go-to-position
18 5 go-to-position
demo ;

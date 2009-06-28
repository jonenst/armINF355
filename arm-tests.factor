! Copyright (C) 2009 Your name.
! See http://factorcode.org/license.txt for BSD license.
USING: arm arm.private tools.test kernel accessors math locals math.functions io bit-arrays sequences namespaces arrays math.bitwise prettyprint math.constants io.encodings.binary io.servers.connection io.binary io.sockets calendar threads fry ;
IN: arm.tests
QUALIFIED: arm.private


[ f ] [ 90 90 check-angles ] unit-test
[ f ] [ 190 -90 check-angles ] unit-test
[ t ] [ 90 -90 check-angles ] unit-test

! Valeurs calculées par factor quand le bras marche du tonnerre, donc a priori justes..
[ 10+5/22 ] [ 15 22 point boa N ] unit-test
[ 1+225/484 ] [ 15 22 point boa A ] unit-test
[ -13-229/242 ] [ 15 22 point boa arm.private:B ] unit-test
[ -120-195/484 ] [ 15 22 point boa C ] unit-test

[ 4 ] [ 3 4 1 delta2 ] unit-test
[ 2.0 ] [ 3 4 1 delta ] unit-test
[ 1.0 -1.0 ] [ 1 0 -1 eq-solve ] unit-test

! pour être en 22 15 avec la pince, il faut mettre le point intermediaire en 0 15
[ 15 ] [ 0 22 15 point boa y-from-x ] unit-test

! Comment faire ce test ...?
! [ T{ point f 13.96332863187588 -5.479548660084625 } T{ point f 0.0 15.0 } ] [ 22 15 point boa intersect ] unit-test

[ 45.0 ] [ 10 10 point boa angle-point to-degrees ] unit-test
[ 45.0 ] [ 10 10 point boa 1 1 point boa angle-vector to-degrees round ] unit-test


[ 90.0 -90.0 ] [ 22 15 point boa intersect-angles [ 2drop ] 2dip [ to-degrees ] bi@ ] unit-test

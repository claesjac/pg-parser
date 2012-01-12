use strict;
use warnings;

use Test::More qw(no_plan);
BEGIN { use_ok('Pg::Parser') or BAIL_OUT "Can't use Pg::Parser" };

Pg::Parser::PLpgSQL->parse(<<__BODY__);
DECLARE
_GoldenRatio numeric := 1.61803398874989;
_V numeric;
_F bigint;
_C bigint;
BEGIN
IF _N >= 80 THEN
    RETURN 23416728348462100;
END IF;
_V  := (_GoldenRatio ^  _N ) / sqrt(5);
_F := floor(_V);
_C = ceil(_V);
IF _V - _F < _C - _V THEN
    RETURN _F;
ELSE
    RETURN _C;
END IF;
END;
__BODY__

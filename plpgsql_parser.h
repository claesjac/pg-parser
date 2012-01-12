#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include <postgres.h>

extern SV *plpgsql_parse(const char *);

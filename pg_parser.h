#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include <postgres.h>
#include <parser/parser.h>

extern SV *pg_parse(const char *);
extern SV *pg_parse_list_to_av(List *);
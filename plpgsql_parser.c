#include "plpgsql_parser.h"
#include <parser/parse_node.h>
#include <plpgsql.h>

SV *plpgsql_parse(const char *src) {
    int parse_rc;    
    ResourceOwner owner;
    ResourceOwner previous_owner = CurrentResourceOwner;
    
    owner = ResourceOwnerCreate(NULL, "plpgsql_parse");
    CurrentResourceOwner = owner;
    
    plpgsql_scanner_init(src);    
        
    plpgsql_ns_init();
    plpgsql_DumpExecTree = true;
    
    parse_rc = plpgsql_yyparse();
    
    plpgsql_scanner_finish();

    CurrentResourceOwner = previous_owner;
    
    ResourceOwnerRelease(owner, RESOURCE_RELEASE_LOCKS, false, true);
    
    return NULL;
}

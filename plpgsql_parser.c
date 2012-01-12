#include "plpgsql_parser.h"
#include <utils/memutils.h>
#include <parser/parse_node.h>
#include <plpgsql.h>

SV *plpgsql_parse(const char *src) {
    int parse_rc;    
    ResourceOwner owner;
    ResourceOwner previous_owner = CurrentResourceOwner;
    PLpgSQL_function *function;
    MemoryContext func_cxt;
	
    owner = ResourceOwnerCreate(NULL, "plpgsql_parse");
    CurrentResourceOwner = owner;
    
    plpgsql_scanner_init(src);    
    
    plpgsql_error_funcname = "test_function";
    plpgsql_curr_compile = function;
    
    function = (PLpgSQL_function *) MemoryContextAllocZero(TopMemoryContext, sizeof(PLpgSQL_function));
	
	func_cxt = AllocSetContextCreate(TopMemoryContext,
        "PL/pgSQL function context",
        ALLOCSET_DEFAULT_MINSIZE,
        ALLOCSET_DEFAULT_INITSIZE,
        ALLOCSET_DEFAULT_MAXSIZE
    );
    
    compile_tmp_cxt = MemoryContextSwitchTo(func_cxt);
    
    function->fn_name = "test_function";
//	function->fn_oid = fcinfo->flinfo->fn_oid;
//	function->fn_xmin = HeapTupleHeaderGetXmin(procTup->t_data);
//	function->fn_tid = procTup->t_self;
	function->fn_is_trigger = false;
//	function->fn_input_collation = fcinfo->fncollation;
//	function->fn_cxt = func_cxt;
	function->out_param_varno = 1;		/* set up for no OUT param */
	function->resolve_option = plpgsql_variable_conflict;
	
    plpgsql_ns_init();
    plpgsql_ns_push("test_function");
    
    plpgsql_DumpExecTree = true;

	datums_alloc = 128;
	plpgsql_nDatums = 0;
	/* This is short-lived, so needn't allocate in function's cxt */
	plpgsql_Datums = MemoryContextAlloc(compile_tmp_cxt,
									 sizeof(PLpgSQL_datum *) * datums_alloc);
//	datums_last = 0;
	
    parse_rc = plpgsql_yyparse();
    
    plpgsql_scanner_finish();

    CurrentResourceOwner = previous_owner;
    
    ResourceOwnerRelease(owner, RESOURCE_RELEASE_LOCKS, false, true);
    
    return NULL;
}

#include "pg_parser.h"
#include "pg_node_types.h"

static const char *DEFAULT_NODE_TYPE = "Node";

static SV *pg_parse_node_to_sv(Node *node) {
    SV *sv = newSV(0);
    const char *type = NodeTypes[nodeTag(node)];
    if (type == NULL) {
        type = DEFAULT_NODE_TYPE;
    }
    
    sv_setref_pv(sv, Perl_form("Pg::Parser::Pg::%s", type), node);
    return sv;
}

SV *pg_parse(const char *src) {
    AV          *parsed_statements;
    List        *raw_parsetree_list;
    ListCell    *parsetree_item;

    raw_parsetree_list = raw_parser(src);

    parsed_statements = newAV();
    
    if (raw_parsetree_list == NULL) {
        return &PL_sv_undef;
    }
    
	foreach(parsetree_item, raw_parsetree_list) {
        Node *parsetree = (Node *) lfirst(parsetree_item);
        
        av_push(parsed_statements, pg_parse_node_to_sv(parsetree));
    }
    
    return newRV((SV *) parsed_statements);
}

SV *pg_parse_list_to_av(List *list) {
    AV          *perl_list;
    ListCell    *item;
    
    if (list == NULL) {
        return &PL_sv_undef;
    }

    perl_list = newAV();
    
	foreach(item, list) {
        Node *node = (Node *) lfirst(item);
        
        av_push(perl_list, pg_parse_node_to_sv(node));
    }
    
    return newRV((SV *) perl_list);    
}
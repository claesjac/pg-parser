#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#include <postgres.h>
#include <parser/parser.h>
#include "pg_parser_nodes.h"
#include "pg_node_types.h"

#include "pg_parser.h"
#include "pg_lexer.h"

#include "plpgsql_parser.h"

/* implemented in postgres_embed.c */
extern void InitEmbeddedPostgres(void);
extern void CloseEmbeddedPostgres(void);

MODULE = Pg::Parser     PACKAGE = Pg::Parser::Lexer

Pg::Parser::Lexer
lex(pkg,src)
    SV *pkg;
    const char *src;
    CODE:
        RETVAL = create_lexer(src);
    OUTPUT:
        RETVAL

int
next_token(self)
    Pg::Parser::Lexer self;
    CODE:
        RETVAL = next_lexer_token(self);
    OUTPUT:
        RETVAL
        
void
DESTROY(self)
    Pg::Parser::Lexer self;
    CODE:
        destroy_lexer(self);

INCLUDE: PgParserNodes.xsh
        
MODULE = Pg::Parser     PACKAGE = Pg::Parser

SV *
parse(pkg,src)
    const char *pkg;
    const char *src; 
    CODE:
        RETVAL = pg_parse(src);
    OUTPUT:
        RETVAL
    
void
close_postgres() 
    CODE:
        CloseEmbeddedPostgres();

MODULE = Pg::Parser     PACKAGE = Pg::Parser::PLpgSQL

SV *
parse(pkg,src)
    const char *pkg;
    const char *src;
    CODE:
        RETVAL = plpgsql_parse(src);
    OUTPUT:
        RETVAL

BOOT:
    InitEmbeddedPostgres();    
    
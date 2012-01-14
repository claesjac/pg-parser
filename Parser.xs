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

MODULE = Pg::Parser     PACKAGE = Pg::Parser::Lexer::Token

const char *
type(self)
    Pg::Parser::Lexer::Token self
    CODE:
        RETVAL = token_type(self);
    OUTPUT:
        RETVAL

bool
is_operator(self)
    Pg::Parser::Lexer::Token self
    CODE:
        RETVAL = token_is_operator(self);
    OUTPUT:
        RETVAL
        
size_t
offset(self)
    Pg::Parser::Lexer::Token self
    CODE:
        RETVAL = token_offset(self);
    OUTPUT:
        RETVAL
        
const char *
src(self)
    Pg::Parser::Lexer::Token self
    CODE:
        RETVAL = token_src(self);
    OUTPUT:
        RETVAL

void
DESTROY(self)
Pg::Parser::Lexer::Token self;
    CODE:
        destroy_token(self);
    
MODULE = Pg::Parser     PACKAGE = Pg::Parser::Lexer

Pg::Parser::Lexer
_lex(src)
    const char *src;
    CODE:
        RETVAL = create_lexer(src);
    OUTPUT:
        RETVAL

void
set_ignore_whitespace(self,value)
    Pg::Parser::Lexer self;
    bool value;
    CODE:
        set_lexer_ignore_whitespace(self, value);
    
Pg::Parser::Lexer::Token
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
    init_lexer();
    InitEmbeddedPostgres();    
    
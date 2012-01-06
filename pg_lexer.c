#include <postgres.h>

#include <parser/parser.h>
#include <parser/scanner.h>
#include <parser/gramparse.h>

#include "pg_token_types.h"

struct Pg_Parser_Lexer {
    core_yyscan_t       yyscanner;
	base_yy_extra_type  yyextra;
	int			        yyresult;    
    YYLTYPE             prev_end_yylloc;
    bool                ignore_whitespace;
    const char          *src;
};

typedef struct Pg_Parser_Lexer Pg_Parser_Lexer;

Pg_Parser_Lexer *create_lexer(const char *src) {
    Pg_Parser_Lexer *lexer;
    
    lexer = (Pg_Parser_Lexer *) calloc(1, sizeof(Pg_Parser_Lexer));
    lexer->ignore_whitespace = true;
    lexer->src = strdup(src);
    lexer->yyscanner = scanner_init(src, &(lexer->yyextra.core_yy_extra),
							 ScanKeywords, NumScanKeywords);

	/* base_yylex() only needs this much initialization */
	lexer->yyextra.have_lookahead = false;
	
    return lexer;
}

int next_lexer_token(Pg_Parser_Lexer *lexer) {
    core_YYSTYPE        yylval;
    YYLTYPE             yylloc;

    yylval.ival = 0;
    
    int token = core_yylex(&yylval, &yylloc, lexer->yyscanner);

    if (token) {
        char *part = NULL;
        size_t len;
        
        fprintf(stderr, "Got token: %d %s\n", token, TokenTypes[token]);
        if (TokenTypes[token] != NULL) {
            /* The only tokens who use ival are these */
            if (token == ICONST || token == PARAM ) {
                part = calloc(64, sizeof(char));
                sprintf(part, "%d", yylval.ival);
                len = strlen(part);
            }
            else {
                len = strlen(yylval.str);
                part = strndup(lexer->src + yylloc, len);
            }
        
            fprintf(stderr, "'%s' from %d to %d\n", part, yylloc, yylloc + len);
            lexer->prev_end_yylloc = yylloc + len;        
        }
    }
    
    return token;
}

void destroy_lexer(Pg_Parser_Lexer *lexer) {
    scanner_finish(lexer->yyscanner);
    free(lexer);
}
#include <postgres.h>

#include <parser/parser.h>
#include <parser/scanner.h>
#include <parser/gramparse.h>

#include "pg_token_types.h"

#define MAKE_FIXED_TOKEN_FUNC(NAME, LENGTH) static void NAME (core_YYSTYPE *yylval, size_t *l) { *l = LENGTH; }

struct Pg_Parser_Lexer_Token {
    int     type;
    char    *src;
    size_t  offset;
};
    
typedef struct Pg_Parser_Lexer_Token Pg_Parser_Lexer_Token;

struct Pg_Parser_Lexer {
    core_yyscan_t           yyscanner;
	base_yy_extra_type      yyextra;
	int			            yyresult;    
    YYLTYPE                 prev_end_yylloc;
    bool                    ignore_whitespace;
    const char              *src;
    Pg_Parser_Lexer_Token   *prev_token;
};

typedef struct Pg_Parser_Lexer Pg_Parser_Lexer;

static void (*convert_token[NUM_TOKENS + 1])(core_YYSTYPE *, size_t *);

static char buff[128];

static void ival_token(core_YYSTYPE *yylval, size_t *len) {
    sprintf(buff, "%d", yylval->ival);
    *len = strlen(buff);
}

static void str_token(core_YYSTYPE *yylval, size_t *len) {
    *len = strlen(yylval->str);
}

MAKE_FIXED_TOKEN_FUNC(typecast_token, 2)
MAKE_FIXED_TOKEN_FUNC(int_p_token, 3)
MAKE_FIXED_TOKEN_FUNC(char_p_token, 4)
MAKE_FIXED_TOKEN_FUNC(op_token, 1)
MAKE_FIXED_TOKEN_FUNC(timestamp_token, 9)
MAKE_FIXED_TOKEN_FUNC(with_token, 4)
MAKE_FIXED_TOKEN_FUNC(as_token, 2)

void init_lexer(void) {
    int i = 0;
    for (i = 0; i < NUM_TOKENS; i++) {
        convert_token[i] = NULL;
    }
                     
    convert_token[OP_NOT]           =   convert_token[OP_NUMBER_SIGN]   =
    convert_token[OP_MODULO]        =   convert_token[OP_AND]           =
    convert_token[OPEN_PAREN]       =   convert_token[CLOSE_PAREN]      =
    convert_token[OP_MULT]          =   convert_token[OP_PLUS]          =
    convert_token[COMMA]            =   convert_token[OP_MINUS]         =
    convert_token[DOT]              =   convert_token[OP_DIV]           =
    convert_token[COLON]            =   convert_token[SEMICOLON]        =
    convert_token[OP_LESS]          =   convert_token[OP_EQUALS]        =
    convert_token[OP_GREATER]       =   convert_token[OP_QUESTION_MARK] =
    convert_token[OP_AT]            =   convert_token[OPEN_BRACKET]     =
    convert_token[CLOSE_BRACKET]    =   convert_token[OP_XOR]           =
    convert_token[OP_ACCENT]        =   convert_token[OP_NEG]           =
    op_token;
    
    convert_token[ICONST] = convert_token[PARAM] = ival_token;

    convert_token[CREATE]           =   convert_token[TABLE]            =
    convert_token[SELECT]           =   convert_token[IDENT]            = 
    convert_token[FROM]             =   convert_token[INTEGER]          = 
    convert_token[UPDATE]           =   convert_token[SET]              =
    convert_token[WHERE]            =   convert_token[Op]               =
    str_token;
    
    convert_token[AS] = as_token;
    convert_token[TIMESTAMP] = timestamp_token;
    convert_token[WITH] = with_token;
    convert_token[TYPECAST] = typecast_token;
    convert_token[CHAR_P] = char_p_token;
    convert_token[INT_P] = int_p_token;
}

Pg_Parser_Lexer *create_lexer(const char *src) {
    Pg_Parser_Lexer *lexer;
    
    lexer = (Pg_Parser_Lexer *) calloc(1, sizeof(Pg_Parser_Lexer));
    lexer->ignore_whitespace = true;
    lexer->prev_token = NULL;
    lexer->prev_end_yylloc = 0;
    lexer->src = strdup(src);
    lexer->yyscanner = scanner_init(src, &(lexer->yyextra.core_yy_extra),
							 ScanKeywords, NumScanKeywords);

	/* base_yylex() only needs this much initialization */
	lexer->yyextra.have_lookahead = false;
	
    return lexer;
}

void set_lexer_ignore_whitespace(Pg_Parser_Lexer *lexer, bool ignore_whitespace) {
    lexer->ignore_whitespace = ignore_whitespace;
}

Pg_Parser_Lexer_Token *next_lexer_token(Pg_Parser_Lexer *lexer) {
    core_YYSTYPE    yylval;
    YYLTYPE         yylloc;
    void            (*converter)(core_YYSTYPE *, size_t *);
    size_t          len;
    Pg_Parser_Lexer_Token *token = NULL;
    
    /* This is a saved token from a whitespace injection,
       that we should return instead of getting next token
    */
    if (lexer->prev_token) {
        token = lexer->prev_token;
        lexer->prev_token = NULL;
        return token;
    }

    yylval.ival = 0;
    
    int t = core_yylex(&yylval, &yylloc, lexer->yyscanner);

    if (t) {
        len = 0;
        
        if (TokenTypes[t] != NULL) {
            buff[0] = '\0';
            converter = convert_token[t];
            
            if (converter) {
                converter(&yylval, &len);
            }
            
            if (len) {
                memcpy(buff, lexer->src + yylloc, len);
                buff[len] = '\0';
            }
            
        }

        token = (Pg_Parser_Lexer_Token *) calloc(1, sizeof(Pg_Parser_Lexer_Token));
        token->type = t;    
        token->src = strdup(buff);
        token->offset = yylloc;
        
        /* Check if we should inject a whitespace and if so
           postpone the last token until next call */
        if (lexer->ignore_whitespace == false) {
            if (yylloc > lexer->prev_end_yylloc) {
                lexer->prev_token = token;
            
                token = (Pg_Parser_Lexer_Token *) calloc(1, sizeof(Pg_Parser_Lexer_Token));
                token->type = WHITESPACE;
                token->offset = lexer->prev_end_yylloc;
                token->src = strndup(lexer->src + lexer->prev_end_yylloc, yylloc - lexer->prev_end_yylloc);
            }
        }
        
        lexer->prev_end_yylloc = yylloc + len;                
    }
    
    return token;
}

const char *token_type(Pg_Parser_Lexer_Token *token) {
    return TokenTypes[token->type];
}

const char *token_src(Pg_Parser_Lexer_Token *token) {
    return token->src;
}

bool token_is_operator(Pg_Parser_Lexer_Token *token) {
    return token->type == Op || strstr(TokenTypes[token->type], "OP_") == TokenTypes[token->type] ? true : false;
}

size_t token_offset(Pg_Parser_Lexer_Token *token) {
    return token->offset;
}

void destroy_token(Pg_Parser_Lexer_Token *token) {
    free(token->src);
    free(token);
}

void destroy_lexer(Pg_Parser_Lexer *lexer) {
    scanner_finish(lexer->yyscanner);
    free(lexer);
}
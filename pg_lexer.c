#include <postgres.h>

#include <parser/parser.h>
#include <parser/scanner.h>
#include <parser/gramparse.h>

#include "pg_token_types.h"

#define MAKE_FIXED_TOKEN_FUNC(NAME, LENGTH) static void NAME (core_YYSTYPE *yylval, size_t *l) { *l = LENGTH; }

struct Pg_Parser_Lexer_Token {
    int     type;
    char    *src;
    int     offset;
    int     line;
    int     column;
};
    
typedef struct Pg_Parser_Lexer_Token Pg_Parser_Lexer_Token;

struct Pg_Parser_Lexer {
    core_yyscan_t           yyscanner;
	base_yy_extra_type      yyextra;
	int			            yyresult;    
    YYLTYPE                 prev_end_yylloc;
    bool                    ignore_whitespace;
    const char              *src;
    int                     *line_offsets;
    int                     line_count;
    int                     last_token_line;
    Pg_Parser_Lexer_Token   *prev_token;
};

typedef struct Pg_Parser_Lexer Pg_Parser_Lexer;

static void (*convert_token[NUM_TOKENS + 1])(core_YYSTYPE *, size_t *);

static char buff[128];

static void iconst_token(core_YYSTYPE *yylval, size_t *len) {
    sprintf(buff, "%d", yylval->ival);
    *len = strlen(buff);
}

static void param_token(core_YYSTYPE *yylval, size_t *len) {
    iconst_token(yylval, len);
    *len += 1;
}

static void str_token(core_YYSTYPE *yylval, size_t *len) {
    *len = strlen(yylval->str);
}

static void sconst_token(core_YYSTYPE *yylval, size_t *len) {
    *len = strlen(yylval->str) + 2;
}

MAKE_FIXED_TOKEN_FUNC(typecast_token, 2)
MAKE_FIXED_TOKEN_FUNC(op_token, 1)

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
    
    convert_token[ICONST] = iconst_token;
    convert_token[PARAM] = param_token;

    /* Keywords */
#ifdef PG_KEYWORD
#undef PG_KEYWORD
#endif

#define PG_KEYWORD(str, token, type) convert_token[token] = str_token;
#include <parser/kwlist.h>
    
    convert_token[TYPECAST] = typecast_token;
    convert_token[IDENT] = str_token;
    convert_token[Op] = str_token;
    convert_token[SCONST] = sconst_token;
}

#define NUM_START_LINES 1024

static void build_line_offsets(Pg_Parser_Lexer *lexer) {
    const char *scan_ptr = lexer->src;
    int *line_offsets;
    int current_line = 0;
    
    line_offsets = (int *) calloc(NUM_START_LINES, sizeof(int));
    line_offsets[current_line++] = 0;
    
    while (*scan_ptr) {        
        if (*scan_ptr == '\n' || *scan_ptr == '\r') {
            scan_ptr++;
            if (*scan_ptr == '\n') {
                scan_ptr++;
            }
            
            line_offsets[current_line++] = scan_ptr - lexer->src;
        }
        scan_ptr++;
    }
    
    lexer->line_offsets = line_offsets;
    lexer->line_count = current_line;
    lexer->last_token_line = 0;
}

void calculate_token_position(Pg_Parser_Lexer *lexer, Pg_Parser_Lexer_Token *token) {
    uint32_t i = lexer->last_token_line ? lexer->last_token_line - 1 : 0;
    
    int *line_offsets = lexer->line_offsets;
    while (i < lexer->line_count && line_offsets[i] <= token->offset) {
        i++;
    }

    token->line = i;
    token->column = token->offset - line_offsets[i - 1] + 1;
    lexer->last_token_line = token->line;
}


Pg_Parser_Lexer *create_lexer(const char *src) {
    Pg_Parser_Lexer *lexer;
    
    lexer = (Pg_Parser_Lexer *) calloc(1, sizeof(Pg_Parser_Lexer));
    lexer->ignore_whitespace = true;
    lexer->prev_token = NULL;
    lexer->prev_end_yylloc = 0;
    lexer->src = strdup(src);
    
    build_line_offsets(lexer);
    
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
    size_t          w_len;
    int             t;
    
    /* This is a saved token from a whitespace injection,
       that we should return instead of getting next token
    */
    if (lexer->prev_token) {
        token = lexer->prev_token;
        lexer->prev_token = NULL;
        return token;
    }

    yylval.ival = 0;
    
    t = core_yylex(&yylval, &yylloc, lexer->yyscanner);

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
        calculate_token_position(lexer, token);
        
        /* Check if we should inject a whitespace and if so
           postpone the last token until next call */
        if (lexer->ignore_whitespace == false) {
            if (yylloc > lexer->prev_end_yylloc) {
                lexer->prev_token = token;
            
                token = (Pg_Parser_Lexer_Token *) calloc(1, sizeof(Pg_Parser_Lexer_Token));
                token->type = WHITESPACE;
                token->offset = lexer->prev_end_yylloc;
                w_len = yylloc - lexer->prev_end_yylloc;
                token->src = calloc(w_len + 1, sizeof(char));
                token->src = memcpy(token->src, lexer->src + lexer->prev_end_yylloc, w_len);
                token->src[w_len] = '\0';
                calculate_token_position(lexer, token);
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

int token_offset(Pg_Parser_Lexer_Token *token) {
    return token->offset;
}

int token_line(Pg_Parser_Lexer_Token *token) {
    return token->line;    
}

int token_column(Pg_Parser_Lexer_Token *token) {
    return token->column;    
}

void destroy_token(Pg_Parser_Lexer_Token *token) {
    free(token->src);
    free(token);
}

void destroy_lexer(Pg_Parser_Lexer *lexer) {
    scanner_finish(lexer->yyscanner);
    free(lexer->src);
    free(lexer->line_offsets);
    free(lexer);
}
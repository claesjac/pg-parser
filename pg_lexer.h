typedef void * Pg__Parser__Lexer__Token;
typedef void * Pg__Parser__Lexer;

extern void init_lexer(void);
extern Pg__Parser__Lexer create_lexer(const char *);
extern void destroy_lexer(Pg__Parser__Lexer);
extern Pg__Parser__Lexer__Token next_lexer_token(Pg__Parser__Lexer);
extern const char *token_type(Pg__Parser__Lexer__Token);
extern const char *token_src(Pg__Parser__Lexer__Token);
extern void destroy_token(Pg__Parser__Lexer__Token);
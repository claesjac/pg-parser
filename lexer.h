typedef void * Pg__Parser__Lexer;

extern Pg__Parser__Lexer create_lexer(const char *);
extern void destroy_lexer(Pg__Parser__Lexer);
extern int next_lexer_token(Pg__Parser__Lexer);
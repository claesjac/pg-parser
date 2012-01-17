#!/usr/bin/perl

use 5.014;
use warnings;

use Pg::Parser;

my $src = do { local $/; <>};
my $lexer = Pg::Parser::Lexer->lex($src, { ignore_whitespace => 1 });

while (my $t = $lexer->next_token) {
    my $src = $t->src;
    $src =~ s/\n/\\n/g;
    say "Token '${src}' at line ", $t->line, 
        " column ", $t->column,
        " is of type: ", $t->type;
}
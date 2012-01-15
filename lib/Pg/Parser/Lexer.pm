package Pg::Parser::Lexer;

use strict;
use warnings;

sub lex {
    my ($pkg, $src, $attrs) = @_;
    
    $attrs = {} unless ref $attrs eq "HASH";
    
    my $lexer = _lex($src);
    
    $lexer->set_ignore_whitespace($attrs->{ignore_whitespace} // 1);
    
    return $lexer;
}

sub read_all {
    my $self = shift;
    
    my @tokens;
    while(my $token = $self->next_token) {
        push @tokens, $token;
    }
    
    return \@tokens;
}
1;
__END__
# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Pg-Parser.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use strict;
use warnings;

use Data::Dumper qw(Dumper);

use Test::More qw(no_plan);
BEGIN { use_ok('Pg::Parser') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

my @tests;

while (<DATA>) {
    chomp;
    my $sql = $_;
    my @types = map uc, split/\s*,\s*/, do { $_ = <DATA>; chomp; $_ };
    my @values = split/\s*,\s*/, do { $_ = <DATA>; chomp; $_ };
    
    push @tests, [ $sql, \@types, \@values ];
    
    # Expect separator
    my $sep = <DATA>;
    chomp $sep;
    BAIL_OUT "Expected separator --- but got $sep" unless $sep eq "---";
}

for my $test (@tests) {
    my $lexer = Pg::Parser::Lexer->lex($test->[0]);
    
    while (my $token = $lexer->next_token) {
        my $type = shift @{$test->[1]};
        my $src = shift @{$test->[2]};
        
        is ($token->type, $type);
        is ($token->src, $src);            
    }
}

__DATA__
SELECT 1
SELECT, ICONST
SELECT, 1
---

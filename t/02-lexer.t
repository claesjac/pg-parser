# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Pg-Parser.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use strict;
use warnings;

use Data::Dumper qw(Dumper);
use Text::CSV_XS;

use Test::More qw(no_plan);
BEGIN { use_ok('Pg::Parser') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

my @tests;

my $csv = Text::CSV_XS->new({ allow_whitespace => 1});

while (<DATA>) {
    chomp;
    my $sql = $_;
    my @types = map uc, split/\s*,\s*/, do { $_ = <DATA>; chomp; $_ };    
    $csv->parse(scalar <DATA>) or BAIL_OUT "CSV parsing failed because of " . $csv->error_diag;
    
    push @tests, [ $sql, \@types, [$csv->fields] ];
    
    # Expect separator
    my $sep = <DATA>;
    chomp $sep;
    BAIL_OUT "Expected separator --- but got $sep" unless $sep eq "---";
}

for my $test (@tests) {
    my $lexer = Pg::Parser::Lexer->lex($test->[0]);
    
    while (my $token = $lexer->next_token) {
        my $expect_type = shift @{$test->[1]};
        my $expect_src = shift @{$test->[2]};
                
        is ($token->type, $expect_type);
        is ($token->src, $expect_src);            
    }
}

__DATA__
SELECT 1
SELECT, ICONST
SELECT, 1
---
Create Table Foo ( id INT, bar TimeStamp WITh TZ )
CREATE, TABLE, IDENT, OPEN_PAREN, IDENT, INT_P, COMMA, IDENT, TIMESTAMP, WITH, IDENT, CLOSE_PAREN
Create, Table, Foo, (, id, INT, ",", bar, TimeStamp, WITh, TZ, )
---
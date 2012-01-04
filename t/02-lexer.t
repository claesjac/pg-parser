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

my $lexer = Pg::Parser::Lexer->lex("SELECT bar::char FROM Foo");
isa_ok($lexer, "Pg::Parser::Lexer");

my $token = $lexer->next_token();
ok($token);
$token = $lexer->next_token();
ok($token);
$token = $lexer->next_token();
ok($token);
$token = $lexer->next_token();
ok($token);
$token = $lexer->next_token();
ok(!$token);
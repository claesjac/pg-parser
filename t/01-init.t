# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Pg-Parser.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use strict;
use warnings;

use Test::More qw(no_plan);
BEGIN { use_ok('Pg::Parser') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

my $parse_trees = Pg::Parser->parse("SELECT 1 FROM DUAL");
ok(defined $parse_trees);
is(@$parse_trees, 1);

my $node = shift @$parse_trees;
isa_ok($node, "Pg::Parser::Pg::SelectStmt");
is($node->type, "SelectStmt");
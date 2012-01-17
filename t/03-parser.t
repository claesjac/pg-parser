use strict;
use warnings;

use Test::More qw(no_plan);
BEGIN { use_ok('Pg::Parser') or BAIL_OUT "Can't use Pg::Parser" };

my $parse_trees = Pg::Parser->parse("SELECT x, y AS z FROM foo;");
ok(defined $parse_trees);
is(@$parse_trees, 1);

my $node = shift @$parse_trees;
isa_ok($node, "Pg::Parser::Pg::SelectStmt");
diag $node->type;
is($node->type, "SelectStmt");

my $from = $node->from_clause;
is (scalar @$from, 1);
isa_ok($from->[0], "Pg::Parser::Pg::RangeVar");
is ($from->[0]->relname, "foo");

my $cols = $node->target_list;
is (scalar @$cols, 2);
isa_ok($cols->[0], "Pg::Parser::Pg::ResTarget");
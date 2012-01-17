#!/usr/bin/perl

use 5.014;
use warnings;

use Pg::Parser;

my $parse_trees = Pg::Parser->parse(q{
SELECT foo.MAX(x), MAX(y) AS max_y, z
  FROM positions;
  
SELECT COUNT(*) AS num, MIN(y)
  FROM positions;
});

for my $tree (@$parse_trees) {
    next unless $tree->type eq "SelectStmt";

    my $cols = $tree->target_list;
    for my $col (@$cols) {
        next unless $col->type eq "ResTarget";    
        next unless $col->val->type eq "FuncCall";
        next if $col->name;

        my $funcname = join ".", map $_->str_value, @{$col->val->funcname};
        
        say "Warning, function call to '${funcname}' in ",
            "target list without alias at offset: ", 
            $col->location;
    }
}
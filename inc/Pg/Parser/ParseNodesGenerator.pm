package Pg::Parser::ParseNodesGenerator;

use strict;
use warnings;

sub generate {
    my ($self, $pg_src) = @_;
    
    my %types;
    my %enums;
    # Read all type declarations
    my @type_order;
    my @enum_order;
    
    for my $file ("value.h", "nodes.h", "primnodes.h", "parsenodes.h") {
        my $parse_nodes_path = "${pg_src}/src/include/nodes/${file}";
        open my $in, "<", $parse_nodes_path or die "Can't open $parse_nodes_path because of: $!";
    
        my $current_type;
        my $current_enum;
        my $last_enum_val;
        
        while (<$in>) {
            if (!$current_enum && /typedef enum (\w+)/) {
                $current_enum = $1;
                $last_enum_val = 0;
                push @enum_order, $current_enum;
                next;
            }
            if ($current_enum && /\} $current_enum;/) {
                undef $current_type;
                undef $current_enum;
                next;
            }
            
            if (!$current_type && /typedef struct (\w+)/) {
                $current_type = $1;
                push @type_order, $current_type;
                next;
            }
            if ($current_type && /\} $current_type;/) {
                undef $current_type;
                undef $current_enum;
                next;
            }
            
            if ($current_type && /^\s*(\w+)\s*(\*)?\s*(\w+)\s*;/) {
                my ($type, $name, $ptr) = ($1, $3, $2);
                $types{$current_type}->{$name} = [$type, defined $ptr ? 1 : 0];
            }
            elsif ($current_enum && /^\s*(\w+)(?:\s*=\s*(\d+))?/) {
                $last_enum_val = defined $2 ? $2 : $last_enum_val + 1;
                $enums{$current_enum}->{$1} = $last_enum_val;                
            }
        }
        
        close $in;
    }
        
    # Generate typemap entries
    open my $typemap, ">>", "typemap" or die "Can't open typemap because of: $!";
    for my $type (@type_order) {
        printf $typemap "%-50s T_PTROBJ\n", "Pg::Parser::Pg::$type";
    }
    close $typemap;
    
    open my $type_out, ">", "parser_nodes.h" or die "Can't open parser_nodes.h";
    open my $out, ">", "ParserNodes.xsh" or die "Can't open ParserNodes.xs: $!";
 
    print $out q/
MODULE = Pg::Parser    PACKAGE = Pg::Parser::Pg::Value

const char *
val_str(self)
    Pg::Parser::Pg::Value self;
    PREINIT:
        Value *v;
    CODE:
        v = (Value *) self; 
        RETVAL = v->val.str;
    OUTPUT:
        RETVAL


const char *
type(self)
    Pg::Parser::Pg::Value self;
    PREINIT:
        Value *v;
    CODE:
        v = (Value *) self; 
        RETVAL = NodeTypes[nodeTag(v)];
    OUTPUT:
        RETVAL


IV
val_ival(self)
    Pg::Parser::Pg::Value self;
    PREINIT:
        Value *v;
    CODE:
        v = (Value *) self; 
        RETVAL = v->val.ival;
    OUTPUT:
        RETVAL
        
/;

    # Write all types (except Value)
    for my $type (@type_order) {
        print $type_out "typedef $type * Pg__Parser__Pg__$type;\n";

        next if $type eq "Value";

        print $out "MODULE = Pg::Parser    PACKAGE = Pg::Parser::Pg::$type\n";
        
        
        while (my ($member, $kind) = each %{$types{$type}}) {
            my $opt_getaddr = "";
            
            my $output = kind_to_output($kind, \%types, \%enums);
            next unless $output;
            my $name = $member;

            $name =~ s/([a-z])([A-Z])/lc(${1}) . "_" . lc($2)/ge;

            if ($kind->[0] eq "Expr" && !$kind->[1] && $member eq "xpr") {
                $output = "const char *";
                $member = "xpr.type";
                $name = "xpr_type";
                $kind->[0] = "NodeTag";
            }
            
            if ($kind->[0] eq "Value" && !$kind->[1]) {
                $opt_getaddr = "&";
            }
            if ($kind->[0] eq "CreateStmt" && !$kind->[1]) {
                $opt_getaddr = "&";
            }
            
            print $out qq{
$output
$name(self)
    Pg::Parser::Pg::$type self;
    PREINIT:
        $type *v;
    CODE:
        v = ($type *) self;
};
    if ($kind->[0] eq "NodeTag") {
        print $out qq{        RETVAL = NodeTypes[nodeTag(v)];};
    }
    elsif ($kind->[0] eq "List") {
        print $out qq{        RETVAL = pg_list_to_av(v->$member);}
    }
    else {
        print $out "        RETVAL = $opt_getaddr(v->$member);";
    }
            print $out qq{
    OUTPUT:
        RETVAL

};
        }
    }
    close $out;
} 

sub kind_to_output {
    my ($kind, $types, $enums) = @_;

    if ($kind->[0] eq "Bitmapset") {
        return;
    }

    if (exists $types->{$kind->[0]}) {
        return "Pg::Parser::Pg::" . $kind->[0];
    }
    elsif ($kind->[0] eq "NodeTag") {
        return "const char *";
    }
    elsif (exists $enums->{$kind->[0]}) {
        return "IV";
    }
    elsif ($kind->[0] eq "NodeTag") {
        return "const char *";
    }
    elsif ($kind->[0] eq "List") {
        return "SV *";
    }
    elsif ($kind->[0] eq "char" && $kind->[1]) {
        return "const char *";
    }
    elsif ($kind->[0] =~ /u?_?int\d*/ || $kind->[0] =~ /^Oid|Index|Offset|AttrNumber|AclMode|bits32|$/) {
        return "IV";
    }
    
    return $kind->[0];
}

1;
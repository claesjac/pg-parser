use 5.014001;
use warnings;

use App::Info::RDBMS::PostgreSQL;
use App::Info::Handler::Prompt;
use List::Util qw(max);
use ExtUtils::MakeMaker;

use inc::Pg::Parser::ParseNodesGenerator;

# This part nicked from DBD::Pg Makefile.PL (c) Turnstep

my $POSTGRES_INCLUDE;
my $POSTGRES_LIB;
my $POSTGRES_BIN;
my $POSTGRES_SRC;

# We need the version information to properly set compiler options later
# Use App::Info to get the data we need.
my $p = App::Info::Handler::Prompt->new;
my $pg = App::Info::RDBMS::PostgreSQL->new(on_unknown => $p);

my ($major_ver, $minor_ver, $patch, $conf, $bindir) = map {$pg->$_}
    qw/major_version minor_version patch_version configure bin_dir/;

my $serverversion = 0;
my $defaultport = 0;

if (defined $major_ver) {
    $serverversion = sprintf '%d%.02d%.02d', $major_ver, $minor_ver, $patch;
    $defaultport = $conf =~ /with-pgport=(\d+)/ ? $1 : 5432;
}

# We set POSTGRES_INCLUDE and POSTGRES_LIB from the first found of:
# 1. environment variable
# 2. App::Info::RDBMS::PostgreSQL information
# 3. subdirectory of $ENV{POSTGRES_HOME}

$POSTGRES_INCLUDE = $ENV{POSTGRES_INCLUDE} || $pg->inc_dir || "$ENV{POSTGRES_HOME}/include";
$POSTGRES_LIB = $ENV{POSTGRES_LIB} || $pg->lib_dir || "$ENV{POSTGRES_HOME}/lib";
$POSTGRES_BIN = $ENV{POSTGRES_BIN} || $pg->bin_dir || "$ENV{POSTGRES_HOME}/bin";
$POSTGRES_SRC = $ENV{POSTGRES_SRC} || "$ENV{POSTGRES_HOME}/src";

my $os = $^O;
print "PostgreSQL version: $serverversion (default port: $defaultport)\n";
my $showhome = $ENV{POSTGRES_HOME} || '(not set)';
print "POSTGRES_HOME: $showhome\n";
my $showinc = $POSTGRES_INCLUDE || '(not set)';
print "POSTGRES_INCLUDE: $showinc\n";
my $showlib = $POSTGRES_LIB || '(not set)';
print "POSTGRES_LIB: $showlib\n";
my $showbin = $POSTGRES_BIN || '(not set)';
print "POSTGRES_BIN: $showbin\n";
 
my $baddir = 0;
sub does_path_exist {
    my ($path_name, $path) = @_;
 
    return if ! defined $path or ! length $path or -d $path;
    printf "The value of %s points to a non-existent directory: %s\n",
        $path_name, $path;
    $baddir++;
    return;
}
 
does_path_exist('POSTGRES_HOME', $ENV{POSTGRES_HOME});
does_path_exist('POSTGRES_INCLUDE',  $POSTGRES_INCLUDE);
does_path_exist('POSTGRES_BIN',  $POSTGRES_BIN);
does_path_exist('POSTGRES_SRC', $POSTGRES_SRC);

# Remove previous typemap if it exists
unlink "typemap";
open my $typemap, ">", "typemap" or die "Can't open typemap because of: $!";
print $typemap "TYPEMAP\n\n";
printf $typemap "%-50s T_PTROBJ\n", "Pg::Parser::Lexer";
printf $typemap "%-50s T_PTROBJ\n", "Pg::Parser::Lexer::Token";
close $typemap;

# Generate node type names
{
    open my $in, "<", "$POSTGRES_SRC/src/include/nodes/nodes.h" or die "Can't open nodes.h in Postgres includes because of: $!";
    my $last_val = -1;
    my @node_types;
    while (<$in>) {
        chomp;
        if (/typedef enum NodeTag/../\} NodeTag/) {
            unless (m{/\*}..m{\*/}) { # Please do not nest /**/
                if (/T_(\w+)(?:\s*=\s*(\d+))?/) {
                    $last_val = defined $2 ? $2 : $last_val + 1;
                    $node_types[$last_val] = [$1, $last_val];
                }
            }
        }
    }
    close $in;

    open my $out, ">", "pg_node_types.h" or die "Can't open node_types.h because of: $!";
    print $out q/
static const char *NodeTypes[] = {
/;

    print $out join ",\n", map { defined $_ ? qq{"$_->[0]" /* $_->[1] */} : "NULL" } @node_types;

    print $out q/
};
/;

    close $out;
}

# Generate token type names
{
    open my $in, "<", "$POSTGRES_SRC/src/backend/parser/gram.c" or die "Can't open gram.c in Postgres source because of: $!";
    
    my $last_val = 0;
    my @token_types;
    while (<$in>) {
        chomp;
        if (/enum yytokentype \{/../\};/) {
            if (/(\w+)\s*=\s*(\d+),/) {
                $token_types[$2] = [$1, $2];
            }
        }
    }
    close $in;

    # Once char ops
    $token_types[33] = ["OP_NOT", 33];
    $token_types[35] = ["OP_NUMBER_SIGN", 35];
    $token_types[37] = ["OP_MODULO", 37];
    $token_types[38] = ["OP_AND", 38];
    $token_types[40] = ["OPEN_PAREN", 40];
    $token_types[41] = ["CLOSE_PAREN", 41];
    $token_types[42] = ["OP_MULT", 42];
    $token_types[43] = ["OP_PLUS", 43];
    $token_types[44] = ["COMMA", 44];
    $token_types[45] = ["OP_MINUS", 45];    
    $token_types[46] = ["DOT", 46];
    $token_types[47] = ["OP_DIV", 47];
    $token_types[58] = ["COLON", 58];
    $token_types[59] = ["SEMICOLON", 59];
    $token_types[60] = ["OP_LESS", 60];
    $token_types[61] = ["OP_EQUALS", 61];
    $token_types[62] = ["OP_GREATER", 62];
    $token_types[63] = ["OP_QUESTION_MARK", 63];
    $token_types[64] = ["OP_AT", 64];
    $token_types[91] = ["OPEN_BRACKET", 91];
    $token_types[93] = ["CLOSE_BRACKET", 93];
    $token_types[94] = ["OP_XOR", 94];
    $token_types[96] = ["OP_ACCENT", 96];
    $token_types[124] = ["OP_OR", 124];
    $token_types[126] = ["OP_NEG", 126];

    
    my $max_token_id = max map $_->[1], grep defined, @token_types;
    
    $max_token_id++;
    
    $token_types[$max_token_id] = ["WHITESPACE", $max_token_id];
    $max_token_id++;
    
    open my $out, ">", "pg_token_types.h" or die "Can't open token_types.h because of: $!";
    print $out q/
static const char *TokenTypes[] = {
/;

    print $out join ",\n", map { defined $_ ? qq{"$_->[0]" /* $_->[1] */} : "NULL" } @token_types;
    print $out q/
};

/;    
    print $out join "\n", map { "#define $_->[0] $_->[1]" } grep { defined } @token_types;
    

    print $out "\n\n#define NUM_TOKENS $max_token_id\n";

    close $out;

}

Pg::Parser::ParseNodesGenerator->generate($POSTGRES_SRC);

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'Pg::Parser',
    VERSION_FROM      => 'lib/Pg/Parser.pm', # finds $VERSION
    PREREQ_PM         => {}, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/Pg/Parser.pm', # retrieve abstract from module
       AUTHOR         => 'Claes Jakobsson <claes@local>') : ()),
    LIBS              => ["-L$POSTGRES_LIB -lpostgres"], # e.g., '-lm'
    DEFINE            => '', # e.g., '-DHAVE_SOMETHING'
    INC               => "-I$POSTGRES_SRC/src/include -I$POSTGRES_SRC/src/pl/plpgsql/src -I$POSTGRES_INCLUDE -I.", # e.g., '-I. -I/usr/include/other'
	# Un-comment this if you add C files to link with later:
    OBJECT            => 'Parser.o pg_lexer.o pg_parser.o postgres_embed.o', # link all the C files too
);

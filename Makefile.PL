use 5.014001;
use App::Info::RDBMS::PostgreSQL;
use App::Info::Handler::Prompt;
use ExtUtils::MakeMaker;

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

# Generate node type names
{
    open my $in, "<", "$POSTGRES_SRC/src/include/nodes/nodes.h" or die "Can't open nodes.h in Postgres includes because of: $!";
    my $last_val = 0;
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

    open my $out, ">", "node_types.h" or die "Can't open node_types.h because of: $!";
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
    
    open my $out, ">", "token_types.h" or die "Can't open token_types.h because of: $!";
    print $out q/
static const char *TokenTypes[] = {
/;

    print $out join ",\n", map { defined $_ ? qq{"$_->[0]" /* $_->[1] */} : "NULL" } @token_types;
    print $out q/
};

/;

    print $out join "\n", map { "#define $_->[0] $_->[1]" } grep { defined } @token_types;
    close $out;
}

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
    INC               => "-I$POSTGRES_SRC/src/include -I$POSTGRES_INCLUDE -I.", # e.g., '-I. -I/usr/include/other'
	# Un-comment this if you add C files to link with later:
    OBJECT            => '$(O_FILES)', # link all the C files too
);

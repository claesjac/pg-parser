use 5.014001;
use App::Info::RDBMS::PostgreSQL;
use App::Info::Handler::Prompt;
use ExtUtils::MakeMaker;

# This part nicked from DBD::Pg Makefile.PL (c) Turnstep

my $POSTGRES_INCLUDE;
my $POSTGRES_LIB;

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
     
my $os = $^O;
print "PostgreSQL version: $serverversion (default port: $defaultport)\n";
my $showhome = $ENV{POSTGRES_HOME} || '(not set)';
print "POSTGRES_HOME: $showhome\n";
my $showinc = $POSTGRES_INCLUDE || '(not set)';
print "POSTGRES_INCLUDE: $showinc\n";
my $showlib = $POSTGRES_LIB || '(not set)';
print "POSTGRES_LIB: $showlib\n";
 
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
    INC               => "-I$POSTGRES_INCLUDE -I.", # e.g., '-I. -I/usr/include/other'
	# Un-comment this if you add C files to link with later:
    # OBJECT            => '$(O_FILES)', # link all the C files too
);

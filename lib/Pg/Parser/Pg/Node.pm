package Pg::Parser::Pg::Node;

use strict;
use warnings;

use Carp qw(croak);

our $AUTOLOAD;
sub AUTOLOAD {
    my $self = shift;
    
    my ($sub) = $AUTOLOAD =~ /.*::(\w+)$/;
    return if $sub eq "DESTROY";
    
    my $pkg = "Pg::Parser::Pg::" . $self->type;
    my $cv = $pkg->can($sub);
    
    croak qq{Can't locate object method "${sub}" via package "${pkg}"} unless $sub;
    
    return $cv->($self);
}

1;
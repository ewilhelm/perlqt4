package Qt::slots;

# meta-hackery tools
my $A = sub {my $n = shift; no strict 'refs'; \@{$n}};
my $H = sub {my ($n) = @_; no strict 'refs'; no warnings 'once'; \%{$n}};
my $SET = sub {my ($n, $v) = @_; no strict 'refs'; no warnings 'once';
    ${$n} = $v};
my $ISUB = sub {my ($n, $s) = @_; no strict 'refs'; *{$n} = $s};

use strict;
use warnings;
use Carp;

#
# Proposed usage:
#
# use Qt::slots changeSomething => ['int'];
#

use Qt;

sub import {
    my $self = shift;
    croak "Odd number of arguments in slot declaration" if @_%2;
    my $caller = $self eq 'Qt::slots' ? (caller)[0] : $self;
    my(%slots) = @_;

    my $meta = $H->($caller . '::META');

    # The perl metaObject holds info about signals and slots, inherited
    # sig/slots, etc.  This is what actually causes perl-defined sig/slots to
    # be executed.
    $ISUB->("${caller}::metaObject", sub {
        return Qt::_internal::getMetaObject($caller);
    }) unless defined &{"${caller}::metaObject"};

    Qt::_internal::installqt_metacall( $caller ) unless defined &{$caller."::qt_metacall"};
    foreach my $fullslotname ( keys %slots ) {

        # Determine the slot return type, if there is one
        my @returnParts = split / +/, $fullslotname;
        my $slotname = pop @returnParts; # Remove actual method name
        my $returnType = @returnParts ? join ' ', @returnParts : undef;

        # Build the signature for this slot
        my $signature = join '', ("$slotname(", join(',', @{$slots{$fullslotname}}), ')');

        # Normalize the signature, might not be necessary
        $signature = Qt::MetaObject::normalizedSignature(
            $signature )->data();

        my $slot = {
            name => $slotname,
            signature => $signature,
            returnType => $returnType,
        };

        push @{$meta->{slots}}, $slot;
    }
}

1;

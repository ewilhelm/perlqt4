package Qt::signals;

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
# use Qt::signals changeSomething => ['int'];
#

use Qt;

sub import {
    my $self = shift;
    croak "Odd number of arguments in signal declaration" if @_%2;
    my $caller = $self eq 'Qt::signals' ? (caller)[0] : $self;
    my(%signals) = @_;

    my $meta = $H->($caller . '::META');

    # The perl metaObject holds info about signals and slots, inherited
    # sig/slots, etc.  This is what actually causes perl-defined sig/slots to
    # be executed.
    $ISUB->("${caller}::metaObject", sub {
        return Qt::_internal::getMetaObject($caller);
    }) unless defined &{ "${caller}::metaObject" };

    # This makes any call to the signal name call XS_SIGNAL
    Qt::_internal::installqt_metacall( $caller )
      unless defined &{$caller."::qt_metacall"};

    foreach my $signalname ( keys %signals ) {
        # Build the signature for this signal
        my $signature = 
          "$signalname(" . join(',', @{$signals{$signalname}}) . ')';

        # Normalize the signature, might not be necessary
        $signature = Qt::MetaObject::normalizedSignature(
           $signature )->data();

        my $signal = {
            name => $signalname,
            signature => $signature,
        };

        push @{$meta->{signals}}, $signal;
        Qt::_internal::installsignal("${caller}::$signalname")
          unless defined &{ "${caller}::$signalname" };
    }
}

1;

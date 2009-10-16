use warnings;
use strict;

package MyApp;

use Test::More tests => 5;

use Qt;
use parent qw(Qt::Application);
use Qt::slots
        foo => [],
        slotToSignal => ['int','int'],
        slot => ['int','int'];
use Qt::signals
        signal1 => ['int','int'],
        signalFromSlot => ['int','int'];

sub new {
    my $self = shift->SUPER::new(@_);

    is( ref($self), 'MyApp', 'Correct subclassing' ) or BAIL_OUT("stop there");

    $self->connect($self, SIGNAL 'signal1(int,int)', SLOT 'slotToSignal(int,int)')
      or die "cannot connect";
    $self->connect($self, SIGNAL 'signalFromSlot(int,int)', SLOT 'slot(int,int)');

    # 4) automatic quitting will test Qt sig to custom slot 
    $self->connect($self, SIGNAL 'aboutToQuit()', SLOT 'foo()');

    # 2) Emit a signal to a slot that will emit another signal
    $self->signal1( 5, 4);
    return($self);
}

sub foo {
    ok( 1, 'Qt signal to custom slot' );
}     

sub slotToSignal {
    my $self = shift;
    is(scalar(@_), 2, '2 arguments') or die "something missing";
    is_deeply([@_], [ 5, 4 ], 'Custom signal to custom slot' );
    # 3) Emit a signal to a slot from within a signal
    $self->signalFromSlot( @_ );
}

sub slot {
    my $self = shift;
    is_deeply( \@_, [ 5, 4 ], 'Signal to slot to signal to slot' );
}

1;

package main;

use Qt;

my $app = MyApp->new(\@ARGV);

Qt::Timer::singleShot( 300, $app, SLOT "quit()" );

$app->exec;

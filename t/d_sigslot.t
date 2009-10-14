use warnings;
use strict;

package MyApp;

use Test::More tests => 4;

use Qt;
use parent qw(Qt::Application);
use Qt::slots
        foo => [],
        slotToSignal => ['int','int'],
        slot => ['int','int'];
use Qt::signals
        signal => ['int','int'],
        signalFromSlot => ['int','int'];

sub new {
    my $self = shift->SUPER::new(@_);

    # 1) testing correct subclassing of Qt::Application and this pointer
    is( ref($self), 'MyApp', 'Correct subclassing' ) or BAIL_OUT("stop there");

    $self->connect($self, SIGNAL 'signal(int,int)', SLOT 'slotToSignal(int,int)');
    $self->connect($self, SIGNAL 'signalFromSlot(int,int)', SLOT 'slot(int,int)');

    # 4) automatic quitting will test Qt sig to custom slot 
    $self->connect($self, SIGNAL 'aboutToQuit()', SLOT 'foo()');

    # 2) Emit a signal to a slot that will emit another signal
    signal( 5, 4 );
}

sub foo {
    ok( 1, 'Qt signal to custom slot' );
}     

sub slotToSignal {
    is_deeply( \@_, [ 5, 4 ], 'Custom signal to custom slot' );
    # 3) Emit a signal to a slot from within a signal
    emit signalFromSlot( @_ );
}

sub slot {
    is_deeply( \@_, [ 5, 4 ], 'Signal to slot to signal to slot' );
}

1;

package main;

use Qt;

$a = MyApp->new(\@ARGV);

Qt::Timer::singleShot( 300, $a, SLOT "quit()" );

exit $a->exec;

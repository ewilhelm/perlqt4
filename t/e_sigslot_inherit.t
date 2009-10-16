use warnings;
use strict;

package MyApp;

use Test::More;

use Qt;
use parent qw(Qt::Application);
BEGIN {$INC{'MyApp.pm'} = __FILE__;}
use Qt::slots
        foo => ['int'],
        baz => [];
use Qt::signals
        bar => ['int'];

sub new {
     my $self = shift->SUPER::new(@_);
     $self->connect($self, SIGNAL 'bar(int)', SLOT 'foo(int)');
     $self->connect($self, SIGNAL 'aboutToQuit()', SLOT 'baz()');
     return $self;
}

sub foo {
    my $self = shift;
    # 1) testing correct inheritance of sig/slots
    is($_[0], 3, 'Correct inheritance of sig/slots');
}

sub baz {
    my $self = shift;
    ok( 1 );
}     

sub coincoin {
    my $self = shift;
    is( scalar @_, 2);
    is( ref($self), 'MySubApp');
}

1;

package MySubApp;

use Test::More;

use Qt;
use parent qw(MyApp);

sub new {
    my $self = shift->SUPER::new(@_);
    $self->foo(3);
    return $self;
}

sub baz {
  my $self = shift;

   # 2) testing further inheritance of sig/slots
   ok( 1, 'Further inheritance of sig/slots' );
   $self->SUPER::baz();

   ok( eval { Qt::blue() } );
   ok( !$@ ) or diag( $@ );

   $self->coincoin('a','b');
}

1;

package main;

use Test::More tests => 7;

use Qt;

my $app = MySubApp->new(\@ARGV);

Qt::Timer::singleShot( 300, qApp, SLOT "quit()" );

exit qApp->exec;

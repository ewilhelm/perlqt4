use warnings;
use strict;

use Test::More tests => 3;

use Qt;

my $app;

eval { $app = Qt::Application->new(\@ARGV) };
ok( !+$@, 'Qt::Application constructor' ) or BAIL_OUT($@);

is(ref $app, 'Qt::Application', 'blessed correctly');

eval { qApp->libraryPaths() };
ok( !+$@, 'qApp properly set up' ) or BAIL_OUT($@);

warn "now singleShot()";
Qt::Timer::singleShot( 300, qApp, SLOT 'quit()' );
warn "what?";

ok( !qApp->exec, 'One second event loop' );

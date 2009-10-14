use warnings;
use strict;

use Test::More tests => 4;

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

alarm(2);
ok( !qApp->exec, 'Timer leaves event loop' );
alarm(0);

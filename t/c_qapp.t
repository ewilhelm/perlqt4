use warnings;
use strict;

use Test::More tests => 7;

use Qt;

isa_ok('Qt::Application', 'Qt::CoreApplication');

my $app = eval { Qt::Application->new(\@ARGV) };
ok( !$@, 'Qt::Application constructor' ) or BAIL_OUT($@);
isa_ok($app, 'Qt::Application');
isa_ok($app, 'Qt::CoreApplication');

is(ref $app, 'Qt::Application', 'blessed correctly');

eval { qApp->libraryPaths() };
ok( !$@, 'qApp properly set up' ) or BAIL_OUT($@);

Qt::Timer::singleShot( 300, qApp, SLOT 'quit()' );

alarm(2);
ok( !qApp->exec, 'Timer leaves event loop' );
alarm(0);

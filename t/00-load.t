use warnings;
use strict;

use Test::More tests => 1;

my $package = 'Qt';
use_ok('Qt') or BAIL_OUT('cannot load Qt');

# vim:syntax=perl:ts=2:sw=2:et:sta

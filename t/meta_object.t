#!/usr/bin/perl

use warnings;
use strict;

use Test::More no_plan =>;

use Qt;

my $meta = Qt::Application->metaObject;
ok($meta, 'got metaObject');
is($meta->className, 'QApplication', "got expected classname");

my $meta2 = Qt::_internal::getMetaObject('Qt::Application');
ok($meta2, 'also metaObject');
is($meta2->className, 'QApplication');


# vim:ts=2:sw=2:et:sta

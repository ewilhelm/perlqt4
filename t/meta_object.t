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

{ package Foo; our @ISA = qw(Qt::Application); }

my $fmeta = Foo->metaObject;
ok($fmeta, 'got metaObject');
TODO: { local $TODO = 'Make metaObject work without fiddling.';
  is($fmeta->className, 'Foo');
}
my $fmeta2 = Qt::_internal::getMetaObject('Foo');
ok($fmeta2, 'got metaObject');
is($fmeta2->className, 'Foo');


# vim:ts=2:sw=2:et:sta

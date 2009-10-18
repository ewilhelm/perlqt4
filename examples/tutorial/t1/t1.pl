#!/usr/bin/perl -w

use strict;
use warnings;

use Qt;

sub main {
    my $app = Qt::Application->new(\@ARGV);
    my $hello = Qt::PushButton->new("Hello world!");
    $hello->show();
    exit $app->exec();
}

main();

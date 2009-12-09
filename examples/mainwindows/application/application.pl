#!/usr/bin/perl -w

use strict;

use Qt;
use MainWindow;

sub main {
    my $app = Qt::Application->new( \@ARGV );
    my $mainWin = MainWindow->new();
    $mainWin->show();
    exit $app->exec();
}

main();

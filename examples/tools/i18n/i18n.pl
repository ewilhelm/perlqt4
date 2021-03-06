#!/usr/bin/perl

use strict;
use warnings;

use Qt;
use LanguageChooser;
use MainWindow;

sub main {
    my $app = Qt::Application( \@ARGV );
    my $chooser = LanguageChooser();
    $chooser->show();
    exit $app->exec();
}

main();

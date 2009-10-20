#!/usr/bin/perl

use strict;
use warnings;

package main;

use Qt;
use GameBoard;

sub main {
    my $app = Qt::Application->new( \@ARGV );
    my $widget = GameBoard->new();
    $widget->setGeometry(100, 100, 500, 355);
    $widget->show();
    return $app->exec();
} 

main();

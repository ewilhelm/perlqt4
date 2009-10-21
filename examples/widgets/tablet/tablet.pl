#!/usr/bin/perl

use strict;
use warnings;

use Qt;

use MainWindow;
use TabletApplication;
use TabletCanvas;

# [0]
sub main {
    my $app = TabletApplication->new( \@ARGV );
    my $canvas = TabletCanvas->new();
    $app->setCanvas($canvas);

    my $mainWindow = MainWindow->new($canvas);
    $mainWindow->resize(500, 500);
    $mainWindow->show();

    return $app->exec();
}
# [0]

exit main();

#!/usr/bin/perl -w

use strict;
use warnings;

use Qt;

sub main {
    my $app = Qt::Application->new(\@ARGV);
    my $quit = Qt::PushButton->new("Quit");
    $quit->resize(150, 30);
    my $font = Qt::Font->new("Times", 18, 75);
    $quit->setFont( $font );

    $app->connect( $quit, SIGNAL "clicked()",
                         $app,  SLOT "quit()" );

    $quit->show();

    return $app->exec();
}

main();

#!/usr/bin/perl

use strict;
use warnings;
use Qt;
use DropSiteWindow;

# [main() function]
sub main
{
    my $app = Qt::Application(\@ARGV);
    my $window = DropSiteWindow();
    $window->show();
    return $app->exec();
}
# [main() function]

exit main();

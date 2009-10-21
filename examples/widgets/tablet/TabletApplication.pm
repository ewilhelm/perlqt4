package TabletApplication;

use strict;
use warnings;
use blib;

use Qt;
use parent qw( Qt::Application );

sub setCanvas {
    my $self = shift;
    my ($canvas) = @_;

    $self->{myCanvas} = $canvas;
}

sub myCanvas() {
    my $self = shift;
    return $self->{myCanvas};
}

# [0]
sub event {
    my $self = shift;
    my ($event) = @_;

    if ($event->type() == Qt::Event::TabletEnterProximity() ||
        $event->type() == Qt::Event::TabletLeaveProximity()) {
        CAST( $event, 'Qt::TabletEvent' );
        $self->myCanvas->setTabletDevice(
            $event->device());
        return 1;
    }
    $DB::single=1; # XXX what?
    return $self->SUPER::event($event);
}
# [0]

1;

package CannonField;

use strict;
use warnings;
use blib;

use Qt;
use Qt::isa qw(Qt::Widget);
use Qt::slots setAngle => ['int'];
use Qt::signals angleChanged => ['int'];

sub NEW {
    shift->SUPER::NEW(@_);

    this->{currentAngle} = 45;
    this->setPalette(Qt::Palette(Qt::Color(250,250,200)));
    this->setAutoFillBackground(1);
}

sub setAngle {
    my ( $angle ) = @_;
    if ($angle < 5) {
        $angle = 5;
    }
    if ($angle > 70) {
        $angle = 70;
    }
    if (this->{currentAngle} == $angle) {
        return;
    }
    this->{currentAngle} = $angle;
    this->update();
    emit angleChanged( this->{currentAngle} );
}

sub paintEvent {
    my $painter = Qt::Painter(this);

    $painter->setPen(Qt::NoPen());
    $painter->setBrush(Qt::Brush(Qt::blue()));

    $painter->translate(0, this->rect()->height());
    $painter->drawPie(Qt::Rect(-35, -35, 70, 70), 0, 90 * 16);
    $painter->rotate(-(this->{currentAngle}));
    $painter->drawRect(Qt::Rect(30, -5, 20, 10));
    $painter->end();
}

1;

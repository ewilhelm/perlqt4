package TabletCanvas;

use strict;
use warnings;
use blib;

use Qt;
use parent qw( Qt::Widget );

use Exporter;
use parent qw( Exporter );
our @EXPORT_OK = qw( AlphaPressure AlphaTilt NoAlpha SaturationVTilt 
    SaturationHTilt SaturationPressure NoSaturation LineWidthPressure
    LineWidthTilt NoLineWidth );

use constant {
    AlphaPressure => 1,
    AlphaTilt => 2,
    NoAlpha => 3,
};

use constant {
    SaturationVTilt => 1,
    SaturationHTilt => 2,
    SaturationPressure => 3,
    NoSaturation => 4,
};

use constant {
    LineWidthPressure => 1,
    LineWidthTilt => 2,
    NoLineWidth => 3,
};

sub setAlphaChannelType {
    my $self = shift;
    $self->{alphaChannelType} = shift;
}

sub setColorSaturationType {
    my $self = shift;
    $self->{colorSaturationType} = shift;
}

sub setLineWidthType {
    my $self = shift;
    $self->{lineWidthType} = shift;
}

sub setColor {
    my $self = shift;
    $self->{myColor} = Qt::Color->new(shift);
}

sub color {
    my $self = shift;
    return $self->myColor;
}

sub setTabletDevice {
    my $self = shift;
    $self->{myTabletDevice} = shift;
}

sub maximum {
    my ( $a, $b ) = @_;
    return $a > $b ? $a : $b;
}

sub alphaChannelType() {
    my $self = shift;
    return $self->{alphaChannelType};
}

sub colorSaturationType() {
    my $self = shift;
    return $self->{colorSaturationType};
}

sub lineWidthType() {
    my $self = shift;
    return $self->{lineWidthType};
}

sub pointerType() {
    my $self = shift;
    return $self->{pointerType};
}

sub myTabletDevice() {
    my $self = shift;
    return $self->{myTabletDevice};
}

sub myColor() {
    my $self = shift;
    return $self->{myColor};
}

sub image() {
    my $self = shift;
    return $self->{image};
}

sub myBrush() {
    my $self = shift;
    return $self->{myBrush};
}

sub myPen() {
    my $self = shift;
    return $self->{myPen};
}

sub deviceDown() {
    my $self = shift;
    return $self->{deviceDown};
}

sub polyLine() {
    my $self = shift;
    return $self->{polyLine};
}

# [0]
sub new {
    my ( $class ) = @_;
    my $self = $class->SUPER::new();
    $self->resize(500, 500);
    $self->{myBrush} = Qt::Brush->new();
    $self->{myPen} = Qt::Pen->new();
    $self->initImage();
    $self->setAutoFillBackground(1);
    $self->{deviceDown} = 0;
    $self->setColor( Qt::red() );
    $self->{myTabletDevice} = Qt::TabletEvent::Stylus();
    $self->{alphaChannelType} = NoAlpha;
    $self->{colorSaturationType} = NoSaturation;
    $self->{lineWidthType} = LineWidthPressure;

    return($self);
}

sub initImage {
    my $self = shift;
    my $newImage = Qt::Image->new($self->width(), $self->height(), Qt::Image::Format_ARGB32());
    my $painter = Qt::Painter->new($newImage);
    $painter->fillRect(0, 0, $newImage->width(), $newImage->height(), Qt::white());
    if ($self->image && !$self->image->isNull()) {
        $painter->drawImage(0, 0, $self->image);
    }
    $painter->end();
    $self->{image} = $newImage;
}
# [0]

# [1]
sub saveImage {
    my $self = shift;
    my ($file) = @_;
    return $self->image->save($file);
}
# [1]

# [2]
sub loadImage {
    my $self = shift;
    my ($file) = @_;
    my $success = $self->image->load($file);

    if ($success) {
        $self->update();
        return 1;
    }
    return 0;
}
# [2]

# [3]
sub tabletEvent {
    my $self = shift;
    my ($event) = @_;

    if ( $event->type() == Qt::Event::TabletPress() ) {
        if (!$self->deviceDown) {
            $self->{deviceDown} = 1;
        }
    }
    elsif ( $event->type() == Qt::Event::TabletRelease() ) {
        if ($self->deviceDown) {
            $self->{deviceDown} = 0;
        }
    }
    elsif ( $event->type() == Qt::Event::TabletMove() ) {
        unshift @{$self->polyLine}, $event->pos();
        delete $self->polyLine->[3];

        if ($self->deviceDown) {
            $self->updateBrush($event);
            my $painter = Qt::Painter->new($self->image);
            $self->paintImage($painter, $event);
            $painter->end();
        }
    }
    $self->update();
}
# [3]

# [4]
sub paintEvent {
    my $self = shift;
    my $painter = Qt::Painter->new($self);
    $painter->drawImage(Qt::Point->new(0, 0), $self->image);
    $painter->end();
}
# [4]

# [5]
sub paintImage {
    my $self = shift;
    my ($painter, $event) = @_;

    my $brushAdjust = Qt::Point->new(10, 10);

    my $myTabletDevice = $self->myTabletDevice;
    if ( $myTabletDevice == Qt::TabletEvent::Stylus() ) {
        $painter->setBrush($self->myBrush);
        $painter->setPen($self->myPen);
        $painter->drawLine($self->polyLine->[1], $event->pos());
    }
    elsif ( $myTabletDevice == Qt::TabletEvent::Airbrush() ) {
        $self->myBrush->setColor($self->myColor);
        $self->myBrush->setStyle($self->brushPattern($event->pressure()));
        $painter->setPen(Qt::NoPen());
        $painter->setBrush($self->myBrush);

        foreach my $i (0..2) {
            $painter->drawEllipse(Qt::Rect->new($self->polyLine->[$i] - $brushAdjust,
                                $self->polyLine->[$i] + $brushAdjust));
        }
    }
    elsif ( $myTabletDevice == Qt::TabletEvent::Puck() ||
         $myTabletDevice == Qt::TabletEvent::FourDMouse() ||
         $myTabletDevice == Qt::TabletEvent::RotationStylus() ) {
        warn("This input device is not supported by the example.");
    }
    else {
        warn("Unknown tablet device.");
    }
}
# [5]

# [6]
sub brushPattern {
    my $self = shift;
    my ($value) = @_;
    my $pattern = int(($value) * 100.0) % 7;

    if ( $pattern == 0 ) {
        return Qt::SolidPattern();
    }
    elsif ( $pattern == 1 ) {
        return Qt::Dense1Pattern();
    }
    elsif ( $pattern == 2 ) {
        return Qt::Dense2Pattern();
    }
    elsif ( $pattern == 3 ) {
        return Qt::Dense3Pattern();
    }
    elsif ( $pattern == 4 ) {
        return Qt::Dense4Pattern();
    }
    elsif ( $pattern == 5 ) {
        return Qt::Dense5Pattern();
    }
    elsif ( $pattern == 6 ) {
        return Qt::Dense6Pattern();
    }
    else {
        return Qt::Dense7Pattern();
    }
}
# [6]

# [7]
sub updateBrush {
    my $self = shift;
    my ($event) = @_;

    my ( $hue, $saturation, $value, $alpha );
    $self->myColor->getHsv($hue, $saturation, $value, $alpha);

    my $vValue = int((($event->yTilt() + 60.0) / 120.0) * 255);
    my $hValue = int((($event->xTilt() + 60.0) / 120.0) * 255);
# [7] //! [8]

    my $alphaChannelType = $self->alphaChannelType;
    if ( $alphaChannelType == AlphaPressure ) {
        $self->myColor->setAlpha(int($event->pressure() * 255.0));
    }
    elsif ( $alphaChannelType == AlphaTilt ) {
        $self->myColor->setAlpha(maximum(abs($vValue - 127), abs($hValue - 127)));
    }
    else {
        $self->myColor->setAlpha(255);
    }

# [8] //! [9]
    my $colorSaturationType = $self->colorSaturationType;
    if ( $colorSaturationType == SaturationVTilt ) {
        $self->myColor->setHsv($hue, $vValue, $value, $alpha);
    }
    elsif ( $colorSaturationType == SaturationHTilt ) {
        $self->myColor->setHsv($hue, $hValue, $value, $alpha);
    }
    elsif ( $colorSaturationType == SaturationPressure ) {
        $self->myColor->setHsv($hue, int($event->pressure() * 255.0), $value, $alpha);
    }

# [9] //! [10]
    my $lineWidthType = $self->lineWidthType;
    if ( $lineWidthType == LineWidthPressure ) {
        $self->myPen->setWidthF($event->pressure() * 10 + 1);
    }
    elsif ( $lineWidthType == LineWidthTilt ) {
        $self->myPen->setWidthF(maximum(abs($vValue - 127), abs($hValue - 127)) / 12);
    }
    else {
        $self->myPen->setWidthF(1);
    }

# [10] //! [11]
    if ($event->pointerType() == Qt::TabletEvent::Eraser()) {
        $self->myBrush->setColor(Qt::white());
        $self->myPen->setColor(Qt::white());
        $self->myPen->setWidthF($event->pressure() * 10 + 1);
    } else {
        $self->myBrush->setColor($self->myColor);
        $self->myPen->setColor($self->myColor);
    }
}
# [11]

sub resizeEvent {
    my $self = shift;
    my ($event) = @_;
    $self->initImage();
    $self->{polyLine} = [];
    $self->polyLine->[0] = $self->polyLine->[1] = $self->polyLine->[2] = Qt::Point->new();
}

1;

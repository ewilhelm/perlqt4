package LCDRange;

use strict;
use warnings;
use blib;

use Qt;
use parent qw(Qt::Widget);
use Qt::slots setValue => ['int'],
              setRange => ['int', 'int'];
use Qt::signals valueChanged => ['int'];

sub new {
    my( $class, $parent, $text ) = @_;
    my $self = $class->SUPER::new($parent);

    $self->init();

    if( $text ) {
        $self->setText($text);
    }
    return $self;
}

sub init {
    my $self = shift;

    my $lcd = Qt::LCDNumber->new(2);
    $lcd->setSegmentStyle(Qt::LCDNumber::Filled());

    my $slider = Qt::Slider->new(Qt::Horizontal());
    $slider->setRange(0, 99);
    $slider->setValue(0);
    my $label = Qt::Label->new();

    $label->setAlignment(Qt::AlignHCenter() | Qt::AlignTop());
    $label->setSizePolicy(Qt::SizePolicy::Preferred(), Qt::SizePolicy::Fixed());

    $self->connect($slider, SIGNAL "valueChanged(int)",
                  $lcd, SLOT "display(int)");
    $self->connect($slider, SIGNAL "valueChanged(int)",
                  $self, SIGNAL "valueChanged(int)");

    my $layout = Qt::VBoxLayout->new;
    $layout->addWidget($lcd);
    $layout->addWidget($slider);
    $layout->addWidget($label);
    $self->setLayout($layout);

    $self->setFocusProxy($slider);

    $self->{slider} = $slider;
    $self->{label} = $label;
}

sub value {
    my $self = shift;
    return $self->{slider}->value();
}

sub setValue {
    my $self = shift;
    my ( $value ) = @_;

    $self->{slider}->setValue($value);
}

sub setRange {
    my $self = shift;
    my ( $minValue, $maxValue ) = @_;

    if (($minValue < 0) || ($maxValue > 99) || ($minValue > $maxValue)) {
        Qt::qWarning("LCDRange::setRange(%d, %d)\n" .
                     "\tRange must be 0..99\n" .
                     "\tand minValue must not be greater than maxValue",
                     $minValue, $maxValue);
        return;
    }
    $self->{slider}->setRange($minValue, $maxValue);
}

sub setText {
    my $self = shift;
    my ( $text ) = @_;

    $self->{label}->setText($text);
}

1;

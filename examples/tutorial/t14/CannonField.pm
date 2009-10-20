package CannonField;

use strict;
use warnings;
use blib;

use Math::Trig;

use Qt;
use parent qw(Qt::Widget);
use Qt::slots setAngle    => ['int'],
              setForce    => ['int'],
              shoot       => [],
              newTarget   => [],
              setGameOver => [],
              restartGame => [],
              moveShot    => [];
use Qt::signals hit          => [],
                missed       => [],
                angleChanged => ['int'],
                forceChanged => ['int'],
                canShoot     => ['bool'];

sub new {
    my $self = shift->SUPER::new(@_);

    $self->{currentAngle} = 45;
    $self->{currentForce} = 0;
    $self->{timerCount} = 0;
    my $autoShootTimer = Qt::Timer->new($self);
    $self->{autoShootTimer} = $autoShootTimer;
    $self->connect( $autoShootTimer, SIGNAL 'timeout()', $self, SLOT 'moveShot()' );
    $self->{shootAngle} = 0;
    $self->{shootForce} = 0;
    $self->{target} = Qt::Point->new(0, 0);
    $self->{gameEnded} = 0;
    $self->{barrelPressed} = 0;
    $self->setPalette(Qt::Palette->new(Qt::Color->new(250,250,200)));
    $self->setAutoFillBackground(1);
    $self->{firstTime} = 1;
    $self->newTarget();

    return $self;
}

sub setAngle {
    my $self = shift;
    my ( $angle ) = @_;
    if ($angle < 5) {
        $angle = 5;
    }
    if ($angle > 70) {
        $angle = 70;
    }
    if ($self->{currentAngle} == $angle) {
        return;
    }
    $self->{currentAngle} = $angle;
    $self->update($self->cannonRect());
    $self->angleChanged( $self->{currentAngle} );
}

sub setForce {
    my $self = shift;
    my ( $force ) = @_;
    if ($force < 0) {
        $force = 0;
    }
    if ($self->{currentForce} == $force) {
        return;
    }
    $self->{currentForce} = $force;
    $self->forceChanged( $self->{currentForce} );
}

sub shoot {
    my $self = shift;
    if ($self->isShooting()) {
        return;
    }
    $self->{timerCount} = 0;
    $self->{shootAngle} = $self->{currentAngle};
    $self->{shootForce} = $self->{currentForce};
    $self->{autoShootTimer}->start(5);
    $self->canShoot( 0 );
}

sub newTarget {
    my $self = shift;
    if ($self->{firstTime}) {
        $self->{firstTime} = 0;
        # XXX this is ridiculous
        srand (time ^ $$ ^ unpack "%L*", `ps axww | gzip -f`);
    }

    # 2147483647 is the value of RAND_MAX, defined in stdlib.h, at least on my machine.
    # See the Qt 4.2 documentation on qrand() for more details.
    $self->{target} = Qt::Point->new( 150 + rand(2147483647) % 190, 10 + rand(2147483647) % 255);
    $self->update();
}

sub setGameOver {
    my $self = shift;
    return if ($self->{gameEnded});
    if ($self->isShooting()) {
        $self->{autoShootTimer}->stop();
    }
    $self->{gameEnded} = 1;
    $self->canShoot(0);
    $self->update();
}

sub restartGame {
    my $self = shift;
    if ($self->isShooting()) {
        $self->{autoShootTimer}->stop();
    }
    $self->{gameEnded} = 0;
    $self->update();
    $self->canShoot( 1 );
}

sub moveShot {
    my $self = shift;
    my $region = $self->shotRect();
    $self->{timerCount}++;

    my $shotR = $self->shotRect();

    if ($shotR->intersects($self->targetRect())) {
        $self->{autoShootTimer}->stop();
        $self->canShoot( 1 );
        $self->hit();
    }
    elsif ($shotR->x() > $self->width() || $shotR->y() > $self->height()
           || $shotR->intersects($self->barrierRect())) {
        $self->{autoShootTimer}->stop();
        $self->canShoot( 1 );
        $self->missed();
    }
    else {
        $region = $region->unite($shotR);
    }
    $self->update($region);
}

sub mousePressEvent {
    my $self = shift;
    my ( $event ) = @_;
    return if ${$event->button()} != ${Qt::LeftButton()};
    if ($self->barrelHit($event->pos())) {
        $self->{barrelPressed} = 1;
    }
}

sub mouseMoveEvent {
    my $self = shift;
    my ( $event ) = @_;
    return unless($self->{barrelPressed});
    my $pos = $event->pos();
    if ($pos->x() <= 0) {
        $pos->setX(1);
    }
    if ($pos->y() >= $self->height()) {
        $pos->setY($self->height() - 1);
    }
    my $rad = atan(($self->rect()->bottom() - $pos->y()) / $pos->x());
    $self->setAngle(int(($rad * 180 / 3.14159265) + .5) );
}

sub mouseReleaseEvent {
    my $self = shift;
    my ( $event ) = @_;
    if (${$event->button()} == ${Qt::LeftButton()}){
        $self->{barrelPressed} = 0;
    }
}

my $barrelRect = Qt::Rect->new(30, -5, 20, 10);

sub paintEvent {
    my $self = shift;
    my $painter = Qt::Painter->new($self);

    if ($self->{gameEnded}) {
        $painter->setPen(Qt::Color->new(Qt::black()));
        $painter->setFont(Qt::Font->new("Courier", 48, Qt::Font::Bold()));
        $painter->drawText($self->rect(), Qt::AlignCenter(), "Game Over");
    }
    if ($self->isShooting()){
        $self->paintShot($painter);
    }
    if (!$self->{gameEnded}) {
        $self->paintTarget($painter);
    }
    $self->paintBarrier($painter);
    $self->paintCannon($painter);

    $painter->end();
}

sub paintShot {
    my $self = shift;
    my( $painter ) = @_;
    $painter->setPen(Qt::NoPen());
    $painter->setBrush(Qt::Brush->new(Qt::black()));
    $painter->drawRect($self->shotRect());
}

sub paintTarget {
    my $self = shift;
    my( $painter ) = @_;
    $painter->setPen(Qt::Color->new(Qt::black()));
    $painter->setBrush(Qt::Brush->new(Qt::red()));
    $painter->drawRect($self->targetRect());
}

sub paintBarrier {
    my $self = shift;
    my( $painter ) = @_;
    $painter->setPen(Qt::Color->new(Qt::black()));
    $painter->setBrush(Qt::Brush->new(Qt::yellow()));
    $painter->drawRect($self->barrierRect());
}

sub paintCannon {
    my $self = shift;
    my( $painter ) = @_;
    $painter->setPen(Qt::NoPen());
    $painter->setBrush(Qt::Brush->new(Qt::blue()));

    $painter->save();
    $painter->translate(0, $self->rect()->height());
    $painter->drawPie(Qt::Rect->new(-35, -35, 70, 70), 0, 90 * 16);
    $painter->rotate(-($self->{currentAngle}));
    $painter->drawRect($barrelRect);
    $painter->restore();
}

sub cannonRect {
    my $self = shift;
    my $result = Qt::Rect->new(0, 0, 50, 50);
    $result->moveBottomLeft($self->rect()->bottomLeft());
    return $result;
}

sub shotRect {
    my $self = shift;

    my $gravity = 4;
    my $time = $self->{timerCount} / 20.0;
    my $velocity = $self->{shootForce};
    my $radians = $self->{shootAngle} * 3.14159265 / 180;

    my $velx = $velocity * cos($radians);
    my $vely = $velocity * sin($radians);
    my $x0 = ($barrelRect->right() + 5) * cos($radians);
    my $y0 = ($barrelRect->right() + 5) * sin($radians);
    my $x = $x0 + $velx * $time;
    my $y = $y0 + $vely * $time - 0.5 * $gravity * $time * $time;

    # My round function
    $x = int($x + .5);
    $y = int($y + .5);

    my $result = Qt::Rect->new(0, 0, 6, 6);
    $result->moveCenter(Qt::Point->new( $x, $self->height() - 1 - $y ));
    return $result;
}

sub targetRect {
    my $self = shift;

    my $result = Qt::Rect->new(0, 0, 20, 10);
    $self or die "where did my self go?";
    my $target = $self->{target} or die "where did my target go?";
    $result->moveCenter(Qt::Point->new($target->x(), $self->height() - 1 - $target->y()));
    return $result;
}

sub barrierRect {
    my $self = shift;

    return Qt::Rect->new(145, $self->height() - 100, 15, 99);
}

sub barrelHit {
    my $self = shift;

    my ( $pos ) = @_;
    my $matrix = Qt::Matrix->new;
    $matrix->translate(0, $self->height());
    $matrix->rotate(-($self->{currentAngle}));
    $matrix = $matrix->inverted();
    return $barrelRect->contains($matrix->map($pos));
}

sub isShooting {
    my $self = shift;
    return $self->{autoShootTimer}->isActive();
}

sub sizeHint {
    return Qt::Size->new(400, 300);
}

1;

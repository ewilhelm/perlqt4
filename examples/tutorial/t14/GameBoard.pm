package GameBoard;

use warnings;
use strict;

use Qt;
use parent qw(Qt::Widget);
use Qt::slots fire    => [],
              hit     => [],
              missed  => [],
              newGame => [];

use CannonField;
use LCDRange;

my @widgets;

sub new {
    my $self = shift->SUPER::new(@_);

    my $quit = Qt::PushButton->new("&Quit");
    $quit->setFont(Qt::Font->new("Times", 18, Qt::Font::Bold()));

    $self->connect($quit, SIGNAL "clicked()", qApp, SLOT "quit()");

    my $angle = LCDRange->new(undef, "ANGLE");
    $angle->setRange(5, 70);

    my $force = LCDRange->new(undef, "FORCE");
    $force->setRange(10, 50);

    my $cannonBox = Qt::Frame->new();
    $cannonBox->setFrameStyle(CAST Qt::Frame::WinPanel() | Qt::Frame::Sunken(), 'Qt::WindowFlags');

    my $cannonField = CannonField->new();

    $self->connect($angle, SIGNAL 'valueChanged(int)',
                  $cannonField, SLOT 'setAngle(int)');
    $self->connect($cannonField, SIGNAL 'angleChanged(int)',
                  $angle, SLOT 'setValue(int)');

    $self->connect($force, SIGNAL 'valueChanged(int)',
                  $cannonField, SLOT 'setForce(int)');
    $self->connect($cannonField, SIGNAL 'forceChanged(int)',
                  $force, SLOT 'setValue(int)');

    $self->connect($cannonField, SIGNAL 'hit()',
                  $self, SLOT 'hit()');
    $self->connect($cannonField, SIGNAL 'missed()',
                  $self, SLOT 'missed()');

    my $shoot = Qt::PushButton->new("&Shoot");
    $shoot->setFont(Qt::Font->new("Times", 18, Qt::Font::Bold()));

    $self->connect($shoot, SIGNAL 'clicked()',
                  $self, SLOT 'fire()');
    $self->connect($cannonField, SIGNAL 'canShoot(bool)',
                  $shoot, SLOT 'setEnabled(bool)');

    my $restart = Qt::PushButton->new("&New Game");
    $restart->setFont(Qt::Font->new("Times", 18, Qt::Font::Bold()));

    $self->connect($restart, SIGNAL 'clicked()', $self, SLOT 'newGame()');

    my $hits = Qt::LCDNumber->new(2);
    $hits->setSegmentStyle(Qt::LCDNumber::Filled());

    my $shotsLeft = Qt::LCDNumber->new(2);
    $shotsLeft->setSegmentStyle(Qt::LCDNumber::Filled());

    my $hitsLabel = Qt::Label->new("HITS");
    my $shotsLeftLabel = Qt::Label->new("SHOTS LEFT");

    Qt::Shortcut->new(Qt::KeySequence->new(${Qt::Key_Enter()}), $self, SLOT 'fire()');
    Qt::Shortcut->new(Qt::KeySequence->new(${Qt::Key_Return()}), $self, SLOT 'fire()');
    Qt::Shortcut->new(Qt::KeySequence->new('Ctrl+Q'), $self, SLOT 'close()');

    my $topLayout = Qt::HBoxLayout->new();
    $topLayout->addWidget($shoot);
    $topLayout->addWidget($hits);
    $topLayout->addWidget($hitsLabel);
    $topLayout->addWidget($shotsLeft);
    $topLayout->addWidget($shotsLeftLabel);
    $topLayout->addStretch(1);
    $topLayout->addWidget($restart);

    my $leftLayout = Qt::VBoxLayout->new();
    $leftLayout->addWidget($angle);
    $leftLayout->addWidget($force);

    my $cannonLayout = Qt::VBoxLayout->new();
    $cannonLayout->addWidget($cannonField);
    $cannonBox->setLayout($cannonLayout);

    my $gridLayout = Qt::GridLayout->new();
    $gridLayout->addWidget($quit, 0, 0);
    $gridLayout->addLayout($topLayout, 0, 1);
    $gridLayout->addLayout($leftLayout, 1, 0);
    $gridLayout->addWidget($cannonBox, 1, 1, 2, 1);
    $gridLayout->setColumnStretch(1, 10);
    $self->setLayout($gridLayout);

    $angle->setValue(60);
    $force->setValue(25);
    $angle->setFocus();

    $self->{angle} = $angle;
    $self->{force} = $force;
    $self->{cannonField} = $cannonField;
    $self->{cannonBox} = $cannonBox;
    $self->{shoot} = $shoot;
    $self->{restart} = $restart;
    $self->{hits} = $hits;
    $self->{shotsLeft} = $shotsLeft;

    $self->newGame();
    $self
}

sub fire {
    my $self = shift;
    return if($self->{cannonField}->{gameEnded} || $self->{cannonField}->isShooting());
    $self->{shotsLeft}->display($self->{shotsLeft}->intValue() - 1);
    $self->{cannonField}->shoot();
}

sub hit {
    my $self = shift;
    $self->{hits}->display($self->{hits}->intValue() + 1);
    if ($self->{shotsLeft}->intValue() == 0) {
        $self->{cannonField}->setGameOver();
    }
    else {
        $self->{cannonField}->newTarget();
        emit $self->{cannonField}->canShoot( 1 );
    }
}

sub missed {
    my $self = shift;
    if ($self->{shotsLeft}->intValue() == 0) {
        $self->{cannonField}->setGameOver();
    }
}

sub newGame {
    my $self = shift;

    $self->{shotsLeft}->display(15);
    $self->{hits}->display(0);
    $self->{cannonField}->restartGame();
    $self->{cannonField}->newTarget();
}

1;

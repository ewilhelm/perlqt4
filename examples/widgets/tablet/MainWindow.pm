package MainWindow;

use strict;
use warnings;
use blib;

use Qt;
use parent qw( Qt::MainWindow );
# [0]
use Qt::slots
    brushColorAct => [],
    alphaActionTriggered => ['QAction*'],
    lineWidthActionTriggered => ['QAction*'],
    saturationActionTriggered => ['QAction*'],
    saveAct => [],
    loadAct => [],
    aboutAct => [];

use TabletCanvas;

sub myCanvas() {
    my $self = shift;
    return $self->{myCanvas};
}

sub brushColorAction() {
    my $self = shift;
    return $self->{brushColorAction};
}

sub brushActionGroup() {
    my $self = shift;
    return $self->{brushActionGroup};
}

sub alphaChannelGroup() {
    my $self = shift;
    return $self->{alphaChannelGroup};
}

sub alphaChannelPressureAction() {
    my $self = shift;
    return $self->{alphaChannelPressureAction};
}

sub alphaChannelTiltAction() {
    my $self = shift;
    return $self->{alphaChannelTiltAction};
}

sub noAlphaChannelAction() {
    my $self = shift;
    return $self->{noAlphaChannelAction};
}

sub colorSaturationGroup() {
    my $self = shift;
    return $self->{colorSaturationGroup};
}

sub colorSaturationVTiltAction() {
    my $self = shift;
    return $self->{colorSaturationVTiltAction};
}

sub colorSaturationHTiltAction() {
    my $self = shift;
    return $self->{colorSaturationHTiltAction};
}

sub colorSaturationPressureAction() {
    my $self = shift;
    return $self->{colorSaturationPressureAction};
}

sub noColorSaturationAction() {
    my $self = shift;
    return $self->{noColorSaturationAction};
}

sub lineWidthGroup() {
    my $self = shift;
    return $self->{lineWidthGroup};
}

sub lineWidthPressureAction() {
    my $self = shift;
    return $self->{lineWidthPressureAction};
}

sub lineWidthTiltAction() {
    my $self = shift;
    return $self->{lineWidthTiltAction};
}

sub lineWidthFixedAction() {
    my $self = shift;
    return $self->{lineWidthFixedAction};
}

sub exitAction() {
    my $self = shift;
    return $self->{exitAction};
}

sub saveAction() {
    my $self = shift;
    return $self->{saveAction};
}

sub loadAction() {
    my $self = shift;
    return $self->{loadAction};
}

sub aboutAction() {
    my $self = shift;
    return $self->{aboutAction};
}

sub aboutQtAction() {
    my $self = shift;
    return $self->{aboutQtAction};
}

sub fileMenu() {
    my $self = shift;
    return $self->{fileMenu};
}

sub brushMenu() {
    my $self = shift;
    return $self->{brushMenu};
}

sub tabletMenu() {
    my $self = shift;
    return $self->{tabletMenu};
}

sub helpMenu() {
    my $self = shift;
    return $self->{helpMenu};
}

sub colorSaturationMenu() {
    my $self = shift;
    return $self->{colorSaturationMenu};
}

sub lineWidthMenu() {
    my $self = shift;
    return $self->{lineWidthMenu};
}

sub alphaChannelMenu() {
    my $self = shift;
    return $self->{alphaChannelMenu};
}
# [0]

# [0]
sub new {
    my ($class, $canvas) = @_;
    my $self = $class->SUPER::new();
    $self->{myCanvas} = $canvas;
    $self->createActions();
    $self->createMenus();

    $self->myCanvas->setColor(Qt::red());
    $self->myCanvas->setLineWidthType(TabletCanvas::LineWidthPressure());
    $self->myCanvas->setAlphaChannelType(TabletCanvas::NoAlpha());
    $self->myCanvas->setColorSaturationType(TabletCanvas::NoSaturation());

    $self->setWindowTitle($self->tr('Tablet Example'));
    $self->setCentralWidget($self->myCanvas);
    return($self);
}
# [0]

# [1]
sub brushColorAct {
    my $self = shift;
    my $color = Qt::ColorDialog::getColor($self->myCanvas->color());

    if ($color->isValid()) {
        $self->myCanvas->setColor($color);
    }
}
# [1]

# [2]
sub alphaActionTriggered {
    my $self = shift;
    my ($action) = @_;

    if ($action == $self->alphaChannelPressureAction) {
        $self->myCanvas->setAlphaChannelType(TabletCanvas::AlphaPressure());
    } elsif ($action == $self->alphaChannelTiltAction) {
        $self->myCanvas->setAlphaChannelType(TabletCanvas::AlphaTilt());
    } else {
        $self->myCanvas->setAlphaChannelType(TabletCanvas::NoAlpha());
    }
}
# [2]

# [3]
sub lineWidthActionTriggered {
    my $self = shift;
    my ($action) = @_;

    $DB::single=1; # XXX what?
    if ($action == $self->lineWidthPressureAction) {
        $self->myCanvas->setLineWidthType(TabletCanvas::LineWidthPressure());
    } elsif ($action == $self->lineWidthTiltAction) {
        $self->myCanvas->setLineWidthType(TabletCanvas::LineWidthTilt());
    } else {
        $self->myCanvas->setLineWidthType(TabletCanvas::NoLineWidth());
    }
}
# [3]

# [4]
sub saturationActionTriggered {
    my $self = shift;
    my ($action) = @_;

    if ($action == $self->colorSaturationVTiltAction) {
        $self->myCanvas->setColorSaturationType(TabletCanvas::SaturationVTilt());
    } elsif ($action == $self->colorSaturationHTiltAction) {
        $self->myCanvas->setColorSaturationType(TabletCanvas::SaturationHTilt());
    } elsif ($action == $self->colorSaturationPressureAction) {
        $self->myCanvas->setColorSaturationType(TabletCanvas::SaturationPressure());
    } else {
        $self->myCanvas->setColorSaturationType(TabletCanvas::NoSaturation());
    }
}
# [4]

# [5]
sub saveAct {
    my $self = shift;
    my $path = Qt::Dir::currentPath() . '/untitled.png';
    my $fileName = Qt::FileDialog::getSaveFileName($self, $self->tr('Save Picture'),
                             $path);

    if (!$self->myCanvas->saveImage($fileName)) {
        Qt::MessageBox::information($self, 'Error Saving Picture',
                                 'Could not save the image');
    }
}
# [5]

# [6]
sub loadAct {
    my $self = shift;
    my $fileName = Qt::FileDialog::getOpenFileName($self, $self->tr('Open Picture'),
                                                    Qt::Dir::currentPath());

    if (!$self->myCanvas->loadImage($fileName)) {
        Qt::MessageBox::information($self, 'Error Opening Picture',
                                 'Could not open picture');
    }
}
# [6]

# [7]
sub aboutAct {
    my $self = shift;
    Qt::MessageBox::about($self, $self->tr('About Tablet Example'),
                       $self->tr('This example shows use of a Wacom tablet in Qt'));
}
# [7]

# [8]
sub createActions {
# [8]
    my $self = shift;
    $self->{brushColorAction} = Qt::Action->new($self->tr('&Brush Color...'), $self);
    $self->brushColorAction->setShortcut(Qt::KeySequence->new($self->tr('Ctrl+C')));
    $self->connect($self->brushColorAction, SIGNAL 'triggered()',
            $self, SLOT 'brushColorAct()');

# [9]
    $self->{alphaChannelPressureAction} = Qt::Action->new($self->tr('&Pressure'), $self);
    $self->alphaChannelPressureAction->setCheckable(1);

    $self->{alphaChannelTiltAction} = Qt::Action->new($self->tr('&Tilt'), $self);
    $self->alphaChannelTiltAction->setCheckable(1);

    $self->{noAlphaChannelAction} = Qt::Action->new($self->tr('No Alpha Channel'), $self);
    $self->noAlphaChannelAction->setCheckable(1);
    $self->noAlphaChannelAction->setChecked(1);

    $self->{alphaChannelGroup} = Qt::ActionGroup->new($self);
    $self->alphaChannelGroup->addAction($self->alphaChannelPressureAction);
    $self->alphaChannelGroup->addAction($self->alphaChannelTiltAction);
    $self->alphaChannelGroup->addAction($self->noAlphaChannelAction);
    $self->connect($self->alphaChannelGroup, SIGNAL 'triggered(QAction *)',
            $self, SLOT 'alphaActionTriggered(QAction *)');

# [9]
    $self->{colorSaturationVTiltAction} = Qt::Action->new($self->tr('&Vertical Tilt'), $self);
    $self->colorSaturationVTiltAction->setCheckable(1);

    $self->{colorSaturationHTiltAction} = Qt::Action->new($self->tr('&Horizontal Tilt'), $self);
    $self->colorSaturationHTiltAction->setCheckable(1);

    $self->{colorSaturationPressureAction} = Qt::Action->new($self->tr('&Pressure'), $self);
    $self->colorSaturationPressureAction->setCheckable(1);

    $self->{noColorSaturationAction} = Qt::Action->new($self->tr('&No Color Saturation'), $self);
    $self->noColorSaturationAction->setCheckable(1);
    $self->noColorSaturationAction->setChecked(1);

    $self->{colorSaturationGroup} = Qt::ActionGroup->new($self);
    $self->colorSaturationGroup->addAction($self->colorSaturationVTiltAction);
    $self->colorSaturationGroup->addAction($self->colorSaturationHTiltAction);
    $self->colorSaturationGroup->addAction($self->colorSaturationPressureAction);
    $self->colorSaturationGroup->addAction($self->noColorSaturationAction);
    $self->connect($self->colorSaturationGroup, SIGNAL 'triggered(QAction *)',
            $self, SLOT 'saturationActionTriggered(QAction *)');

    $self->{lineWidthPressureAction} = Qt::Action->new($self->tr('&Pressure'), $self);
    $self->lineWidthPressureAction->setCheckable(1);
    $self->lineWidthPressureAction->setChecked(1);

    $self->{lineWidthTiltAction} = Qt::Action->new($self->tr('&Tilt'), $self);
    $self->lineWidthTiltAction->setCheckable(1);

    $self->{lineWidthFixedAction} = Qt::Action->new($self->tr('&Fixed'), $self);
    $self->lineWidthFixedAction->setCheckable(1);

    $self->{lineWidthGroup} = Qt::ActionGroup->new($self);
    $self->lineWidthGroup->addAction($self->lineWidthPressureAction);
    $self->lineWidthGroup->addAction($self->lineWidthTiltAction);
    $self->lineWidthGroup->addAction($self->lineWidthFixedAction);
    $self->connect($self->lineWidthGroup, SIGNAL 'triggered(QAction *)',
            $self, SLOT 'lineWidthActionTriggered(QAction *)');

    $self->{exitAction} = Qt::Action->new($self->tr('E&xit'), $self);
    $self->exitAction->setShortcut(Qt::KeySequence->new($self->tr('Ctrl+X')));
    $self->connect($self->exitAction, SIGNAL 'triggered()',
            $self, SLOT 'close()');

    $self->{loadAction} = Qt::Action->new($self->tr('&Open...'), $self);
    $self->loadAction->setShortcut(Qt::KeySequence->new($self->tr('Ctrl+O')));
    $self->connect($self->loadAction, SIGNAL 'triggered()',
            $self, SLOT 'loadAct()');

    $self->{saveAction} = Qt::Action->new($self->tr('&Save As...'), $self);
    $self->saveAction->setShortcut(Qt::KeySequence->new($self->tr('Ctrl+S')));
    $self->connect($self->saveAction, SIGNAL 'triggered()',
            $self, SLOT 'saveAct()');

    $self->{aboutAction} = Qt::Action->new($self->tr('A&bout'), $self);
    $self->aboutAction->setShortcut(Qt::KeySequence->new($self->tr('Ctrl+B')));
    $self->connect($self->aboutAction, SIGNAL 'triggered()',
            $self, SLOT 'aboutAct()');

    $self->{aboutQtAction} = Qt::Action->new($self->tr('About &Qt'), $self);
    $self->aboutQtAction->setShortcut(Qt::KeySequence->new($self->tr('Ctrl+Q')));
    $self->connect($self->aboutQtAction, SIGNAL 'triggered()',
            qApp, SLOT 'aboutQt()');
# [10]
}
# [10]

# [11]
sub createMenus {
    my $self = shift;
    $self->{fileMenu} = $self->menuBar()->addMenu($self->tr('&File'));
    $self->fileMenu->addAction($self->loadAction);
    $self->fileMenu->addAction($self->saveAction);
    $self->fileMenu->addSeparator();
    $self->fileMenu->addAction($self->exitAction);

    $self->{brushMenu} = $self->menuBar()->addMenu($self->tr('&Brush'));
    $self->brushMenu->addAction($self->brushColorAction);

    $self->{tabletMenu} = $self->menuBar()->addMenu($self->tr('&Tablet'));

    $self->{lineWidthMenu} = $self->tabletMenu->addMenu($self->tr('&Line Width'));
    $self->lineWidthMenu->addAction($self->lineWidthPressureAction);
    $self->lineWidthMenu->addAction($self->lineWidthTiltAction);
    $self->lineWidthMenu->addAction($self->lineWidthFixedAction);

    $self->{alphaChannelMenu} = $self->tabletMenu->addMenu($self->tr('&Alpha Channel'));
    $self->alphaChannelMenu->addAction($self->alphaChannelPressureAction);
    $self->alphaChannelMenu->addAction($self->alphaChannelTiltAction);
    $self->alphaChannelMenu->addAction($self->noAlphaChannelAction);

    $self->{colorSaturationMenu} = $self->tabletMenu->addMenu($self->tr('&Color Saturation'));
    $self->colorSaturationMenu->addAction($self->colorSaturationVTiltAction);
    $self->colorSaturationMenu->addAction($self->colorSaturationHTiltAction);
    $self->colorSaturationMenu->addAction($self->noColorSaturationAction);

    $self->{helpMenu} = $self->menuBar()->addMenu('&Help');
    $self->helpMenu->addAction($self->aboutAction);
    $self->helpMenu->addAction($self->aboutQtAction);
}
# [11]

1;

package MainWindow;

use strict;
use blib;

use File::Basename qw(basename);

use Qt;
use parent -norequire => qw( Qt::MainWindow );
use Qt::slots
                newFile => [],
                openFile => [],
                save => [],
                saveAs => [],
                about => [],
                documentWasModified => [];

sub new {
    my $self = shift->SUPER::new(@_);

    my $textEdit = Qt::TextEdit->new();
    $self->setCentralWidget($textEdit);
    $self->{textEdit} = $textEdit;

    $self->createActions();
    $self->createMenus();
    $self->createToolBars();
    $self->createStatusBar();

    $self->readSettings();

    $self->connect($textEdit->document(), SIGNAL 'contentsChanged()',
                  $self, SLOT 'documentWasModified()');

    $self->setCurrentFile("");
    return $self;
}

sub closeEvent {
    my $self = shift;
    my ($event) = @_;
    if ($self->maybeSave()) {
        $self->writeSettings();
        $event->accept();
    } else {
        $event->ignore();
    }
}

sub newFile {
    my $self = shift;
    if ($self->maybeSave()) {
        $self->{textEdit}->clear();
        $self->setCurrentFile("");
    }
}

sub openFile {
    my $self = shift;
    if ($self->maybeSave()) {
        my $fileName = Qt::FileDialog::getOpenFileName($self);
        if ($fileName) {
            $self->loadFile($fileName);
        }
    }
}

sub save {
    my $self = shift;
    if (!defined $self->{curFile} || !$self->{curFile}) {
        return $self->saveAs();
    } else {
        return $self->saveFile($self->{curFile});
    }
}

sub saveAs {
    my $self = shift;
    my $fileName = Qt::FileDialog::getSaveFileName($self);
    if (!defined $fileName){
        return 0;
    }

    return $self->saveFile($fileName);
}

sub about {
    my $self = shift;
    Qt::MessageBox::about($self, "About Application",
            "The <b>Application</b> example demonstrates how to " .
               "write modern GUI applications using Qt, with a menu bar, " .
               "toolbars, and a status bar.");
}

sub documentWasModified {
    my $self = shift;
    $self->setWindowModified($self->{textEdit}->document()->isModified());
}

sub createActions {
    my $self = shift;
    my $textEdit = $self->{textEdit};
    my $newAct =  Qt::Action->new(Qt::Icon->new("images/new.png"), "&New", $self);
    $newAct->setShortcut(Qt::KeySequence->new("Ctrl+N"));
    $newAct->setStatusTip("Create a new file");
    $self->connect($newAct, SIGNAL 'triggered()', $self, SLOT 'newFile()');
    $self->{newAct} = $newAct;

    my $openAct = Qt::Action->new(Qt::Icon->new("images/open.png"), "&Open...", $self);
    $openAct->setShortcut(Qt::KeySequence->new("Ctrl+O"));
    $openAct->setStatusTip("Open an existing file");
    $self->connect($openAct, SIGNAL 'triggered()', $self, SLOT 'openFile()');
    $self->{openAct} = $openAct;

    my $saveAct = Qt::Action->new(Qt::Icon->new("images/save.png"), "&Save", $self);
    $saveAct->setShortcut(Qt::KeySequence->new("Ctrl+S"));
    $saveAct->setStatusTip("Save the document to disk");
    $self->connect($saveAct, SIGNAL 'triggered()', $self, SLOT 'save()');
    $self->{saveAct} = $saveAct;

    my $saveAsAct = Qt::Action->new("Save &As...", $self);
    $saveAsAct->setStatusTip("Save the document under a new name");
    $self->connect($saveAsAct, SIGNAL 'triggered()', $self, SLOT 'saveAs()');
    $self->{saveAsAct} = $saveAsAct;

    my $exitAct = Qt::Action->new("E&xit", $self);
    $exitAct->setShortcut(Qt::KeySequence->new("Ctrl+Q"));
    $exitAct->setStatusTip("Exit the application");
    $self->connect($exitAct, SIGNAL 'triggered()', $self, SLOT 'close()');
    $self->{exitAct} = $exitAct;

    my $cutAct = Qt::Action->new(Qt::Icon->new("images/cut.png"), "Cu&t", $self);
    $cutAct->setShortcut(Qt::KeySequence->new("Ctrl+X"));
    $cutAct->setStatusTip("Cut the current selection's contents to the " .
                            "clipboard");
    $self->connect($cutAct, SIGNAL 'triggered()', $textEdit, SLOT 'cut()');
    $self->{cutAct} = $cutAct;

    my $copyAct = Qt::Action->new(Qt::Icon->new("images/copy.png"), "&Copy", $self);
    $copyAct->setShortcut(Qt::KeySequence->new("Ctrl+C"));
    $copyAct->setStatusTip("Copy the current selection's contents to the " .
                             "clipboard");
    $self->connect($copyAct, SIGNAL 'triggered()', $textEdit, SLOT 'copy()');
    $self->{copyAct} = $copyAct;

    my $pasteAct = Qt::Action->new(Qt::Icon->new("images/paste.png"), "&Paste", $self);
    $pasteAct->setShortcut(Qt::KeySequence->new("Ctrl+V"));
    $pasteAct->setStatusTip("Paste the clipboard's contents into the current " .
                              "selection");
    $self->connect($pasteAct, SIGNAL 'triggered()', $textEdit, SLOT 'paste()');
    $self->{pasteAct} = $pasteAct;

    my $aboutAct = Qt::Action->new("&About", $self);
    $aboutAct->setStatusTip("Show the application's About box");
    $self->connect($aboutAct, SIGNAL 'triggered()', $self, SLOT 'about()');
    $self->{aboutAct} = $aboutAct;

    my $aboutQtAct = Qt::Action->new("About &Qt", $self);
    $aboutQtAct->setStatusTip("Show the Qt library's About box");
    $self->connect($aboutQtAct, SIGNAL 'triggered()', Qt::qApp(), SLOT 'aboutQt()');
    $self->{aboutQtAct} = $aboutQtAct;

    $cutAct->setEnabled(0);
    $copyAct->setEnabled(0);
    $self->connect($textEdit, SIGNAL 'copyAvailable(bool)',
                  $cutAct, SLOT 'setEnabled(bool)');
    $self->connect($textEdit, SIGNAL 'copyAvailable(bool)',
                  $copyAct, SLOT 'setEnabled(bool)');
}

sub createMenus {
    my $self = shift;
    my $fileMenu = $self->menuBar()->addMenu("&File");
    $fileMenu->addAction($self->{newAct});
    $fileMenu->addAction($self->{openAct});
    $fileMenu->addAction($self->{saveAct});
    $fileMenu->addAction($self->{saveAsAct});
    $fileMenu->addSeparator();
    $fileMenu->addAction($self->{exitAct});

    my $editMenu = $self->menuBar()->addMenu("&Edit");
    $editMenu->addAction($self->{cutAct});
    $editMenu->addAction($self->{copyAct});
    $editMenu->addAction($self->{pasteAct});

    $self->menuBar()->addSeparator();

    my $helpMenu = $self->menuBar()->addMenu("&Help");
    $helpMenu->addAction($self->{aboutAct});
    $helpMenu->addAction($self->{aboutQtAct});
}

sub createToolBars {
    my $self = shift;
    my $fileToolBar = $self->addToolBar("File");
    $fileToolBar->addAction($self->{newAct});
    $fileToolBar->addAction($self->{openAct});
    $fileToolBar->addAction($self->{saveAct});

    my $editToolBar = $self->addToolBar("Edit");
    $editToolBar->addAction($self->{cutAct});
    $editToolBar->addAction($self->{copyAct});
    $editToolBar->addAction($self->{pasteAct});
}

sub createStatusBar {
    my $self = shift;
    $self->statusBar()->showMessage("Ready");
}

sub readSettings {
    my $self = shift;
    my $settings = Qt::Settings->new("Trolltech", "Application Example");
    my $pos = $settings->value("pos", Qt::Variant->new(Qt::Point->new(200, 200)))->toPoint();
    my $size = $settings->value("size", Qt::Variant->new(Qt::Size->new(400, 400)))->toSize();
    $self->resize($size);
    $self->move($pos);
}

sub writeSettings {
    my $self = shift;
    my $settings = Qt::Settings->new("Trolltech", "Application Example");
    $settings->setValue("pos", Qt::Variant->new($self->pos()));
    $settings->setValue("size", Qt::Variant->new($self->size()));
}

sub maybeSave {
    my $self = shift;
    if ($self->{textEdit}->document()->isModified()) {
        my $ret = Qt::MessageBox::warning($self, "Application",
          "The document has been modified.\n" .
          "Do you want to save your changes?",
          Qt::MessageBox::Save() |
          Qt::MessageBox::Discard() |
          Qt::MessageBox::Cancel()
        );
        if ($ret == Qt::MessageBox::Save()) {
            return save();
        }
        elsif ($ret == Qt::MessageBox::Cancel()) {
            return 0;
        }
    }
    return 1;
}

sub loadFile {
    my $self = shift;
    my ( $fileName ) = @_;

    my $fh;
    unless(open($fh, '<', $fileName)) {
        Qt::MessageBox::warning($self, "Application",
          sprintf("Cannot read file %s:\n%s.", $fileName, $!)
        );
        return 0;
    }

    Qt::Application::setOverrideCursor(Qt::Cursor->new(Qt::WaitCursor()));
    $self->{textEdit}->setPlainText(join "\n", <FH> );
    Qt::Application::restoreOverrideCursor();
    close $fh;

    $self->setCurrentFile($fileName);
    $self->statusBar()->showMessage("File loaded", 2000);
}

sub saveFile {
    my $self = shift;
    my ($fileName) = @_;

    my $fh;
    unless(open($fh, '>', $fileName)) {
        Qt::MessageBox::warning($self, "Application",
          sprintf("Cannot write file %s:\n%s.", $fileName, $!)
        );
        return 0;
    }

    Qt::Application::setOverrideCursor(Qt::Cursor->new(Qt::WaitCursor()));
    print $fh $self->{textEdit}->toPlainText();
    Qt::Application::restoreOverrideCursor();
    close $fh; # XXX is the disk full!?

    $self->setCurrentFile($fileName);
    $self->statusBar()->showMessage("File saved", 2000);
    return 1;
}

sub setCurrentFile {
    my $self = shift;
    my ( $fileName ) = @_;
    $self->{curFile} = $fileName;
    $self->{textEdit}->document()->setModified(0);
    $self->setWindowModified(0);

    my $shownName;
    if (!defined $self->{curFile} || !($self->{curFile})) {
        $shownName = "untitled.txt";
    }
    else {
        $shownName = $self->strippedName($self->{curFile});
    }

    $self->setWindowTitle(sprintf("%s\[*] - %s", $shownName, "Application"));
}

sub strippedName {
    my $self = shift;
    my ( $fullFileName ) = @_;
    return basename( $fullFileName );
}

1;

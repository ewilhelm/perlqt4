use Test::More tests => 27;

use Devel::Peek ();

use strict;
use warnings;
use Qt;

my $app = Qt::Application->new( \@ARGV );

{
    my $widget = Qt::Widget->new();
    # Check refcount
    is ( Devel::Peek::SvREFCNT($widget), 1, 'refcount' );
    # Test Qt::String marshalling
    my $wt = 'Qt::String marshalling works!';
    $widget->setWindowTitle( $wt );
    is ( $widget->windowTitle(), $wt, 'Qt::String' );
}

{
    my $widget = Qt::Widget->new();
    # Test a string that has non-latin characters
    use utf8;
    my $wt = 'ターミナル';
    utf8::upgrade($wt);
    $widget->setWindowTitle( $wt );
    is ( $widget->windowTitle(), $wt, 'Qt::String unicode' );
    no utf8;
}

{
    # Test int marshalling
    my $widget = Qt::Widget->new();
    my $int = 341;
    $widget->resize( $int, $int );
    is ( $widget->height(), $int, 'int' );

    # Test marshalling to int from enum value
    my $textFormat = Qt::TextCharFormat->new();
    $textFormat->setFontWeight( Qt::Font::Bold() );
    is ( $textFormat->fontWeight(), ${Qt::Font::Bold()}, 'enum to int' );
}

{
    # Test double marshalling
    my $double = 3/7;
    my $doubleValidator = Qt::DoubleValidator->new( $double, $double * 2, 5, undef );
    is ( $doubleValidator->bottom(), $double, 'double' );
    is ( $doubleValidator->top(), $double * 2, 'double' );
}

{
    # Test bool marshalling
    my $widget = Qt::Widget->new();
    my $bool = !$widget->isEnabled();
    $widget->setEnabled( $bool );
    is ( $widget->isEnabled(), $bool, 'bool' );
}

{
    # Test int* marshalling
    my ( $x1, $y1, $w1, $h1, $x2, $y2, $w2, $h2 ) = ( 5, 4, 50, 40 );
    my $rect = Qt::Rect->new( $x1, $y1, $w1, $h1 );
    # XXX nobody should have to do it like this.
    $rect->getRect( $x2, $y2, $w2, $h2 );
    ok ( $x1 == $x2 &&
         $y1 == $y2 &&
         $w1 == $w2 &&
         $h1 == $h2,
         'int*' );
}

{
    # Test unsigned int marshalling
    my $label = Qt::Label->new();
    my $hcenter = ${Qt::AlignHCenter()};
    my $top = ${Qt::AlignTop()};
    $label->setAlignment(Qt::AlignHCenter() | Qt::AlignTop());
    my $alignment = $label->alignment();
    is( $alignment, $hcenter|$top, 'unsigned int' );
}

{
    # Test char and uchar marshalling
    my $char = Qt::Char->new( Qt::Int(87) );
    is ( $char->toAscii(), 87, 'signed char' );
    $char = Qt::Char->new( Qt::Uchar('f') );
    is ( $char->toAscii(), ord('f'), 'unsigned char' );
    $char = Qt::Char->new( 'f', 3 );
    is ( $char->row(), 3, 'unsigned char' );
    is ( $char->cell(), ord('f'), 'unsigned char' );
}

{
    # Test short, ushort, and long marshalling
    my $shortSize = length( pack 'S', 0 );
    my $num = 5;
    my $gotNum = 0;
    my $block = Qt::ByteArray->new();
    my $stream = Qt::DataStream->new($block, Qt::IODevice::ReadWrite());
    $stream->operator_leftshift(Qt::Short($num));
    my $streamPos = $stream->device()->pos();
    $stream->device()->seek(0);
    $stream->operator_rightshift(Qt::Short($gotNum));
    is ( $gotNum, $num, 'signed short' );

    $gotNum = 0;
    $stream->device()->seek(0);
    $stream->operator_leftshift(Qt::Ushort($num));
    $stream->device()->seek(0);
    $stream->operator_rightshift(Qt::Ushort($gotNum));
    is ( $gotNum, $num, 'unsigned short' );
    is ( $streamPos, $shortSize, 'long' );
}

{
    # Test some QLists
    my $action1 = Qt::Action->new( 'foo', undef );
    my $action2 = Qt::Action->new( 'bar', undef );
    my $action3 = Qt::Action->new( 'baz', undef );

    # Add some stuff to them...
    $action1->{The} = 'quick';
    $action2->{brown} = 'fox';
    $action3->{jumped} = 'over';

    my $actions = [ $action1, $action2, $action3 ]; 

    my $widget = Qt::Widget->new();
    $widget->addActions( $actions );

    my $gotactions = $widget->actions();

    is_deeply( $actions, $gotactions, 'marshall_ItemList<>' );
}

{
    # Test ambiguous list call
    my $strings = [ qw( The quick brown fox jumped over the lazy dog ) ];
    my $var = Qt::Variant->new( $strings );
    my $newStrings = $var->toStringList();
    is_deeply( $strings, $newStrings, 'Ambiguous list resolution' );
}

{
    # Test marshall_ValueListItem ToSV
    my $shortcut1 = Qt::KeySequence->new( Qt::Key_Enter() );
    my $shortcut2 = Qt::KeySequence->new( Qt::Key_Tab() );

    my $shortcuts = [ $shortcut1, $shortcut2 ];
    my $action = Qt::Action->new( 'Foobar', undef );

    $action->setShortcuts( $shortcuts );
    my $got = $action->shortcuts();
    ok($got, "got shortcuts");
    is(ref($got), 'ARRAY', "ARRAY ref");
    is(scalar(@$got), scalar(@$shortcuts), 'count');

    is_deeply(
      [ map{ $shortcuts->[$_] == $got->[$_] } (0..$#$shortcuts) ],
      [ map{ 1 } (0..$#{$shortcuts}) ],
      'marshall_ValueListItem<> FromSV' );
}

{
    my $tree = Qt::TableView->new( undef );
    my $model = Qt::DirModel->new();

    $tree->setModel( $model );
    my $top = $model->index( Qt::Dir::currentPath() );
    $tree->setRootIndex( $top );

    my $selectionModel = $tree->selectionModel();
    my @child = map({$top->child(0,$_)} 0..3);
    $selectionModel->select( $child[0], Qt::ItemSelectionModel::Select() );
    $selectionModel->select( $child[1], Qt::ItemSelectionModel::Select() );
    $selectionModel->select( $child[2], Qt::ItemSelectionModel::Select() );
    $selectionModel->select( $child[3], Qt::ItemSelectionModel::Select() );

    my $selection = $selectionModel->selection();
    my $indexes = $selection->indexes();
    is($#$indexes, $#child, "index length");

    is_deeply( [ map{ $indexes->[$_] == $child[$_] } (0..$#child) ],
               [ map{ 1 } (0..$#child) ],
               'marshall_ValueListItem<> ToSV' );
}

TODO: {
    todo_skip("findChildren is a stupid name anyway", 2);
    # Test Qt::Object::findChildren
    my $widget = Qt::Widget->new();
    my $childWidget = Qt::Widget->new($widget);
    my $childPushButton = Qt::PushButton->new($childWidget);
    my $children = $widget->findChildren('Qt::Widget');
    is_deeply( $children, [$childWidget, $childPushButton], 'Qt::Object::findChildren' );
    $children = $widget->findChildren('Qt::PushButton');
    is_deeply( $children, [$childPushButton], 'Qt::Object::findChildren' );
}

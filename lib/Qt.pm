package Qt::base;

use strict;
use warnings;

# meta-hackery tools
my $A = sub {my $n = shift; no strict 'refs'; \@{$n}};
my $H = sub {my ($n) = @_; no strict 'refs'; no warnings 'once'; \%{$n}};
my $SET = sub {my ($n, $v) = @_; no strict 'refs'; no warnings 'once';
    ${$n} = $v};
my $ISUB = sub {my ($n, $s) = @_; no strict 'refs'; *{$n} = $s};

sub DESTROY {}

# This subroutine is used to set the context for translation correctly for any
# perl subclasses.  Without it, the context would always be set to the base Qt
# class.
sub tr {
    die "this doesn't actually work";
    my $context = ref Qt::this();
    $context =~ s/^ *//;
    if( !$context ) {
        ($context) = $Qt::AutoLoad::AUTOLOAD =~ m/(.*).:tr$/;
    }
    return Qt::qApp()->translate( $context, @_ );
}

package Qt::DBusReply;

use strict;
use warnings;

sub new {
    my ( $class, $reply ) = @_;
    my $this = bless {}, $class;

    my $error = Qt::DBusError->new($reply);
    $this->{error} = $error;
    if ( $error->isValid() ) {
        $this->{data} = Qt::Variant->new();
        return $this;
    }

    my $arguments = $reply->arguments();
    if ( ref $arguments eq 'ARRAY' && scalar @{$arguments} >= 1 ) {
        $this->{data} = $arguments->[0];
        return $this;
    }

    # This only gets called if the 2 previous ifs weren't
    $this->{error} = Qt::DBusError->new( Qt::DBusError::InvalidSignature(),
                                    'Unexpected reply signature' );
    $this->{data} = Qt::Variant->new();
    return $this;
}

sub isValid {
    my ( $this ) = @_;
    return !$this->{error}->isValid();
}

sub value() {
    my ( $this ) = @_;
    return $this->{data}->value();
}

sub error() {
    my ( $this ) = @_;
    return $this->{error};
}

1;

package Qt::DBusVariant;

use strict;
use warnings;

sub NEW {
    my ( $class, $value ) = @_;
    if ( ref $value eq ' Qt::Variant' ) {
        $class->SUPER::NEW( $value );
    }
    else {
        $class->SUPER::NEW( $value );
    }
}

1;

package Qt::_internal;

use strict;
use warnings;

use Qt::debug;
use Carp;

use List::MoreUtils qw(uniq);

# lookup hashes
our %package2classId;
our %classId2package;
our %classId2class;

# This hash stores integer pointer address->perl SV association.  Used for
# overriding virtual functions, where all you have as an input is a void* to
# the object who's method is being called.  Made visible here for debugging
# purposes.
our %pointer_map;

my %customClasses = (
    'Qt::DBusVariant' => 'Qt::Variant',
);

our $ambiguousSignature = undef;

my %arrayTypes = (
    'const QList<QVariant>&' => {
        value => [ 'QVariant' ]
    },
    'const QStringList&' => {
        value => [ 's', 'Qt::String' ],
    },
);

my %hashTypes = (
    'const QHash<QString, QVariant>&' => {
        value1 => [ 's', 'Qt::String' ],
        value2 => [ 'QVariant' ]
    },
    'const QMap<QString, QVariant>&' => {
        value1 => [ 's', 'Qt::String' ],
        value2 => [ 'QVariant' ]
    },
);

my %matchers = (
  i => qr/^(?:bool|(?:(?:un)?signed )?(?:int|long)|uint|uchar)[*&]?$/,
  n => qr/^(?:float|double)$/,
  # TODO something about the enum
  s => qr/^(?:const )?(?:u?char|(?:QString|QByteArray))[\*&]?$/,
  'Qt::String'  => qr/^(?:const )?QString[\*&]?$/,
  'Qt::CString' => qr/^(?:const )?char ?\*[\*&]?$/,
  'Qt::Int'     => qr/^int[\*&]?$/,
  'Qt::Uint'    => qr/^unsigned int[\*&]?$/,
  'Qt::Bool'    => 'bool',
  'Qt::Short'   => qr/^short[\*&]?$/,
  'Qt::Ushort'  => qr/^unsigned short[\*&]?$/,
  'Qt::Uchar'   => qr/^u(?=nsigned )?char[\*&]?$/,
);

sub install_autoload {
    my ($where) = @_;

    our $AUTOLOAD;
    $SET->("$where\::VERSION", Qt->VERSION);

    # TODO install a can() too

    $ISUB->("$where\::isa", sub {
        my ($package, $what) = @_;
        no strict 'refs';
        local *{"$where\::ISA"} = \@{"$where\::isa"};
        $package->SUPER::isa($what);
    });
    $ISUB->("$where\::AUTOLOAD", sub {
        (my $method = $AUTOLOAD) =~ s/(.*):://;
        my $package = $1;
        DEBUG autoload => "autoloading $where for ($package) $method";

        populate_class($where);
        if(my $sub = $where->can($method)) {
            goto $sub;
        }
        else {
            Carp::croak(
                ref($_[0])
                ? "Can't locate object method " .
                    qq{"$method" via package "$package"}
                : "Undefined subroutine &$package\::$method called"
            );
        }
    });
}

# populate_class installs all of the possible methods
{
    my %om = qw(
      + plus
      - minus
      * star
      = equal
      ! not
      ^ xor
      ~ comp
      | or
      & and
      < lessthan
      > greaterthan
      / slash
    );
    my %ops = (
      qw(
      << leftshift
      >> rightshift
      ),
      '[]'                  => 'list',
      ' bool'               => 'bool',
      ' const char *'       => 'const_char_pointer',
      ' const void *'       => 'const_void_pointer',
      ' const QModelIndex&' => 'const_QModelIndex_and',
      ' int'                => 'int',
      ' QChar'              => 'QChar',
      ' QPointF'            => 'QPointF',
      ' QString'            => 'QString',
      ' QVariant'           => 'Qvariant',
      map({$_ => $om{$_}} keys %om),
      map({$_ => join('', map({$om{$_}} split(//, $_)))}
        qw(^= <= == >= |= -= -- != /= *= &= += ++)),
    );
    my @ok = keys(%ops);
    foreach my $k (@ok) {
      $ops{'operator' . $k} = 'operator_' . delete($ops{$k});
    }
    sub populate_class {
        my ($where) = @_;

        my @isa = @{$A->("$where\::isa")};
        # and populate our parents
        for(@isa) { populate_class($_) if(defined &{"$_\::AUTOLOAD"}) }
        # finally install our ISA array
        @{$A->("$where\::ISA")} = @isa;

        {
          no strict 'refs';
          delete ${"$where\::"}{AUTOLOAD};
          undef @{$A->("$where\::isa")}; # just for kicks
          delete ${"$where\::"}{isa};
        }


        my $id = $package2classId{$where};
        die "cannot populate $where - no id" unless(defined $id);
        my $cxx_class = $classId2class{$id};
        (my $cxx = $cxx_class) =~ s/.*:://;

        die "cannot populate $where - no cxx_class"
            unless(defined $cxx_class);
        my $h = get_methods_for($cxx_class) or die "oh no";

        my $notes = $H->("$where\::_CXXCODE");
        my $code = qq(package $where;\nuse warnings; use strict;\n);
        foreach my $k (sort keys %$h) {
            next if($k =~ m/^~/);
            my $name = $k eq $cxx ? 'new' : ($ops{$k} || $k);
            my $id_list = join(',', @{$h->{$k}});

            $k = '+'.$k if($k eq $cxx); # XXX silly workaround

            if(defined &{"$where\::$name"}) {
                $name = '__'.$name;
            }
            else {
                $notes->{$name} = 1;
            }

            $code .= "sub $name {" .
                "unshift(\@_, '$where', '$k', [$id_list]); " .
                "goto &Qt::_internal::go}\n";
        }
        DEBUG autoload_verbose => "installing $code ";
        eval($code);
        die $@ if($@); # TODO die with line numbers on $code
    }
} # end closure

sub resolver {
  my ($ids, $ptypes) = @_;

  my @found;
  foreach my $id (@$ids) {
    my @qtypes = get_arg_types($id);
    next if(@qtypes != @$ptypes);

    DEBUG verbose_calls =>
      "check (", join(",", @$ptypes),
      ") against (", join(",", @qtypes), ")\n";
    my $ok = 0;
    foreach my $i (0..$#$ptypes) {
      my $p = $ptypes->[$i];
      my $q = $qtypes[$i];
      if(my $m = $matchers{$p}) {
        $q =~ m/$m/ or last;
        DEBUG verbose_calls => "  $p is $q\n";
      }
      elsif($p eq 'a') {
        if($q =~ m/char\*\*/) {
          DEBUG verbose_calls => "  $p is $q\n";
        }
        else {
          my $at = $arrayTypes{$q} or last;
          # XXX validating against content won't make sense unless we do
          # it against the cache match too.
          DEBUG verbose_calls => "  array is maybe $q\n";
          # my @subt = uniq( map{ getSVt( $_ ) } @{$args->[$argNum]} );
          # my @valid = @{$at->{value}};
          # my $good = 1;
          # foreach my $s (@subt) {
          #   if(!grep{ $_ eq $s } @valid) {
          #     $good = 0;
          #     last;
          #   }
          # }
          # if($good) {
          #     $match{$methodId} = [0,$methodIdIdx];
          # }
        }
      }
      elsif($p eq 'r' or $p eq 'u') {
      }
      else {
        # must be an object
        $q =~ s/^(?:const\s+)?(\w*)[&*]?$/$1/g;
        DEBUG verbose_calls => "check $p isa $q\n";
        # XXX getSVt() and enum blessing need alignment
        unless($p eq $q or $p.'s' eq $q) {
            $q = normalize_classname($q);
            last unless($p eq $q or $p->isa($q));
        }
        DEBUG verbose_calls => "  $p isa $q\n";
      }

      $ok++;
    }
    push(@found, $id) if($ok == @$ptypes);
  }
  @found or croak("cannot find matching signature");
  return($found[0]) if(@found == 1);
  carp("too many matching signatures: @found\n");
  return($found[0]);
}

sub go {
    my $class = shift;
    my $method = shift;
    my $id_list = shift;

    # if the object is of this class, treat as an object method
    my $self = (ref($_[0]) and eval{$_[0]->isa($class)}) ?
        shift(@_) : undef;

    $self = shift(@_) if($method =~ s/^\+//); # XXX silly workaround

    DEBUG calls => "$method candidates: ", join(", ", @$id_list);

    my @ptypes = map({getSVt($_)} @_);
    my $id = $#$id_list ? resolver($id_list, \@ptypes) : $id_list->[0];
    # TODO still need to check one id, plus cache stuff

    unshift(@_, $id, $self);
    DEBUG calls => "call $class\::$method() as ",
        join(',', map({defined($_) ? $_ : '*undef*'} @_));
    goto &call_smoke;
}

sub getMetaObject {
    my $class = shift;

    DEBUG meta => "getMetaObject";
    my $meta = $H->($class . '::META');

    # If no signals/slots/properties have been added since the last time this
    # was asked for, return the saved one.
    return $meta->{object} if $meta->{object} and !$meta->{changed};

    # If this is a native Qt class, call metaObject() on that class directly
    if ( $package2classId{$class} ) {
        return $meta->{object} = $class->metaObject;
    }

    # Get the super class's meta object for sig/slot inheritance
    # Look up through ISA to find it
    my $parentMeta = undef;
    my $parentClassId;

    # This seems wrong, it won't work with multiple inheritance
    my $parentClass = $A->($class."::ISA")->[0]; 
    if( !$package2classId{$parentClass} ) {
        DEBUG meta =>
            "  recursive getMetaObject for $class ($parentClass)\n";

        # The parent class is a custom Perl class whose metaObject was
        # constructed at runtime, so we can get it's metaObject from here.
        $parentMeta = getMetaObject( $parentClass );
    }
    else {
        DEBUG meta =>
            "  guessed parent id for $class ($parentClass)\n";
        $parentClassId = $package2classId{$parentClass};
    }

    DEBUG meta => "  now makeMetaData for $class\n";
    # Generate data to create the meta object
    my( $stringdata, $data ) = makeMetaData( $class );
    $meta->{object} = Qt::_internal::make_metaObject(
        $parentClassId,
        $parentMeta,
        $stringdata,
        $data );

    $meta->{changed} = 0;
    return $meta->{object};
}

sub init_class {
    my ($cxxClassName) = @_;

    my $perlClassName = normalize_classname($cxxClassName);
    my $classId = idClass($cxxClassName);

    # Save the association between this perl package and the cxx classId.
    $package2classId{$perlClassName} = $classId;
    $classId2package{$classId} = $perlClassName;
    $classId2class{$classId} = $cxxClassName;

    # Define the inheritance array for this class.
    my @isa = getIsa($classId);
    @isa = $customClasses{$perlClassName}
        if defined $customClasses{$perlClassName};

    # We want the isa array to be the names of perl packages, not c++ class
    # names
    foreach my $super ( @isa ) {
        $super = normalize_classname($super);
    }

    # The root of the tree will be Qt::base
    @isa = ('Qt::base') unless @isa;

    # Defer actual ISA install until populate_class()
    @{$A->($perlClassName.'::isa')} = @isa;

    { # pretend we loaded a .pm file
        (my $pm = $perlClassName . '.pm') =~ s{::}{/}g;
        $INC{$pm} = __FILE__;
    }

    install_autoload($perlClassName);
}

# Args: none
# Returns: none
# Desc: sets up each class
sub init {
    my $classes = getClassList();
    push @{$classes}, keys %customClasses;
    init_class($_) for(@$classes);

    # my $enums = getEnumList();
    # foreach my $enumName (@$enums) {
    #     $enumName =~ s/^const //;
    #     if(@{$A->("${enumName}::ISA")}) {
    #         @{$A->("${enumName}Enum::ISA")} = ('Qt::enum::_overload');
    #     }
    #     else {
    #         @{$A->("${enumName}::ISA")} = ('Qt::enum::_overload');
    #     }
    # }

}

sub makeMetaData {
    my ( $classname ) = @_;

    my $meta = $H->($classname . '::META');

    my $classinfos = $meta->{classinfos};
    my $dbus = $meta->{dbus};
    my $signals = $meta->{signals};
    my $slots = $meta->{slots};

    @{$classinfos} = () if !defined @{$classinfos};
    @{$signals} = () if !defined @{$signals};
    @{$slots} = () if !defined @{$slots};

    # Each entry in 'stringdata' corresponds to a string in the
    # qt_meta_stringdata_<classname> structure.

    #
    # From the enum MethodFlags in qt-copy/src/tools/moc/generator.cpp
    #
    my $AccessPrivate = 0x00;
    my $AccessProtected = 0x01;
    my $AccessPublic = 0x02;
    my $MethodMethod = 0x00;
    my $MethodSignal = 0x04;
    my $MethodSlot = 0x08;
    my $MethodCompatibility = 0x10;
    my $MethodCloned = 0x20;
    my $MethodScriptable = 0x40;

    my $numClassInfos = scalar @{$classinfos};
    my $numSignals = scalar @{$signals};
    my $numSlots = scalar @{$slots};

    my $data = [
        1,                           #revision
        0,                           #str index of classname
        $numClassInfos,              #number of classinfos
        $numClassInfos > 0 ? 10 : 0, #have classinfo?
        $numSignals + $numSlots,     #number of sig/slots
        10 + (2*$numClassInfos),     #have methods?
        0, 0,                        #no properties
        0, 0,                        #no enums/sets
    ];

    my $stringdata = "$classname\0";
    my $nullposition = length( $stringdata ) - 1;

    # Build the stringdata string, storing the indexes in data
    foreach my $classinfo ( @{$classinfos} ) {
        foreach my $keyval ( %{$classinfo} ) {
            my $curPosition = length $stringdata;
            push @{$data}, $curPosition;
            $stringdata .= $keyval . "\0";
        }
    }

    foreach my $signal ( @$signals ) {
        my $curPosition = length $stringdata;

        # Add this signal to the stringdata
        $stringdata .= $signal->{signature} . "\0" ;

        push @$data, $curPosition; #signature
        push @$data, $nullposition; #parameter names
        push @$data, $nullposition; #return type, void
        push @$data, $nullposition; #tag
        if ( $dbus ) {
            push @$data, $MethodScriptable | $MethodSignal | $AccessPublic; # flags
        }
        else {
            push @$data, $MethodSignal | $AccessProtected; # flags
        }
    }

    foreach my $slot ( @$slots ) {
        my $curPosition = length $stringdata;

        # Add this slot to the stringdata
        $stringdata .= $slot->{signature} . "\0";
        push @$data, $curPosition; #signature

        push @$data, $nullposition; #parameter names

        if ( defined $slot->{returnType} ) {
            $curPosition = length $stringdata;
            $stringdata .= $slot->{returnType} . "\0";
            push @$data, $curPosition; #return type
        }
        else {
            push @$data, $nullposition; #return type, void
        }
        push @$data, $nullposition; #tag
        push @$data, $MethodSlot | $AccessPublic; # flags
    }

    push @$data, 0; #eod

    return ($stringdata, $data);
}

# Args: $cxxClassName: the name of a Qt class
# Returns: The name of the associated perl package
# Desc: Given a c++ class name, determine the perl package name
sub normalize_classname {
    my ( $cxxClassName ) = @_;

    # Don't modify the 'Qt' class
    return $cxxClassName if $cxxClassName eq 'Qt';

    my $perlClassName = $cxxClassName;

    if ($cxxClassName =~ m/^Q3/) {
        # Prepend Qt3:: if this is a Qt3 support class
        $perlClassName =~ s/^Q3(?=[A-Z])/Qt3::/;
    }
    elsif ($cxxClassName =~ m/^Q/) {
        # Only prepend Qt:: if the name starts with Q and is followed by
        # an uppercase letter
        $perlClassName =~ s/^Q(?=[A-Z])/Qt::/;
    }

    return $perlClassName;
}

sub Qt::CoreApplication::new {
    my ($class, $argv) = @_;

    my @args = ($0, @$argv);
    my $retval = $class->__new(scalar(@args), \@args);
    Qt::setQApp($retval);
    return($retval);
}
# force populate_class() to make a __new() here
*Qt::Application::new = \&Qt::CoreApplication::new;

package Qt;

use 5.008006;
use strict;
use warnings;

require Exporter;
require XSLoader;
use Devel::Peek;

our $VERSION = '0.01';

our @EXPORT = qw( SIGNAL SLOT emit CAST qApp );

XSLoader::load('Qt', $VERSION);

Qt::_internal::init();

sub SIGNAL ($) { '2' . $_[0] }
sub SLOT ($) { '1' . $_[0] }
sub emit (@) { return pop @_ }
sub CAST ($$) {
    my( $var, $class ) = @_;
    # XXX I suspect this is not even needed
    return bless( ref($var) ? $var : \$var, $class );
}

sub import { goto &Exporter::import }

sub setSignature {
  # XXX cheating should not be necessary
  die "setSignature() not supported";
    $Qt::_internal::ambiguousSignature = shift;
}

{my $qapp; sub setQApp {$qapp = shift;} sub qApp () {$qapp}}

# Called in the DESTROY method for all QObjects to see if they still have a
# parent, and avoid deleting them if they do.
sub Qt::Object::ON_DESTROY {
    package Qt::_internal;
    my $parent = Qt::this()->parent;
    if( defined $parent ) {
        my $ptr = sv_to_ptr(Qt::this());
        ${ $parent->{'hidden children'} }{ $ptr } = Qt::this();
        Qt::this()->{'has been hidden'} = 1;
        return 1;
    }
    return 0;
}

# Never save a QApplication from destruction
sub Qt::Application::ON_DESTROY {
    return 0;
}

$ISUB->('Qt::Variant::value', sub {
    my $this = shift;

    my $type = $this->type();
    if( $type == Qt::Variant::Invalid() ) {
        return;
    }
    elsif( $type == Qt::Variant::Bitmap() ) {
    }
    elsif( $type == Qt::Variant::Bool() ) {
        return $this->toBool();
    }
    elsif( $type == Qt::Variant::Brush() ) {
        return Qt::qVariantValue(Qt::Brush(), $this);
    }
    elsif( $type == Qt::Variant::ByteArray() ) {
        return $this->toByteArray();
    }
    elsif( $type == Qt::Variant::Char() ) {
        return Qt::qVariantValue(Qt::Char(), $this);
    }
    elsif( $type == Qt::Variant::Color() ) {
        return Qt::qVariantValue(Qt::Color(), $this);
    }
    elsif( $type == Qt::Variant::Cursor() ) {
        return Qt::qVariantValue(Qt::Cursor(), $this);
    }
    elsif( $type == Qt::Variant::Date() ) {
        return $this->toDate();
    }
    elsif( $type == Qt::Variant::DateTime() ) {
        return $this->toDateTime();
    }
    elsif( $type == Qt::Variant::Double() ) {
        return $this->toDouble();
    }
    elsif( $type == Qt::Variant::Font() ) {
        return Qt::qVariantValue(Qt::Font(), $this);
    }
    elsif( $type == Qt::Variant::Icon() ) {
        return Qt::qVariantValue(Qt::Icon(), $this);
    }
    elsif( $type == Qt::Variant::Image() ) {
        return Qt::qVariantValue(Qt::Image(), $this);
    }
    elsif( $type == Qt::Variant::Int() ) {
        return $this->toInt();
    }
    elsif( $type == Qt::Variant::KeySequence() ) {
        return Qt::qVariantValue(Qt::KeySequence(), $this);
    }
    elsif( $type == Qt::Variant::Line() ) {
        return $this->toLine();
    }
    elsif( $type == Qt::Variant::LineF() ) {
        return $this->toLineF();
    }
    elsif( $type == Qt::Variant::List() ) {
        return $this->toList();
    }
    elsif( $type == Qt::Variant::Locale() ) {
        return Qt::qVariantValue(Qt::Locale(), $this);
    }
    elsif( $type == Qt::Variant::LongLong() ) {
        return $this->toLongLong();
    }
    elsif( $type == Qt::Variant::Map() ) {
        return $this->toMap();
    }
    elsif( $type == Qt::Variant::Palette() ) {
        return Qt::qVariantValue(Qt::Palette(), $this);
    }
    elsif( $type == Qt::Variant::Pen() ) {
        return Qt::qVariantValue(Qt::Pen(), $this);
    }
    elsif( $type == Qt::Variant::Pixmap() ) {
        return Qt::qVariantValue(Qt::Pixmap(), $this);
    }
    elsif( $type == Qt::Variant::Point() ) {
        return $this->toPoint();
    }
    elsif( $type == Qt::Variant::PointF() ) {
        return $this->toPointF();
    }
    elsif( $type == Qt::Variant::Polygon() ) {
        return Qt::qVariantValue(Qt::Polygon(), $this);
    }
    elsif( $type == Qt::Variant::Rect() ) {
        return $this->toRect();
    }
    elsif( $type == Qt::Variant::RectF() ) {
        return $this->toRectF();
    }
    elsif( $type == Qt::Variant::RegExp() ) {
        return $this->toRegExp();
    }
    elsif( $type == Qt::Variant::Region() ) {
        return Qt::qVariantValue(Qt::Region(), $this);
    }
    elsif( $type == Qt::Variant::Size() ) {
        return $this->toSize();
    }
    elsif( $type == Qt::Variant::SizeF() ) {
        return $this->toSizeF();
    }
    elsif( $type == Qt::Variant::SizePolicy() ) {
        return $this->toSizePolicy();
    }
    elsif( $type == Qt::Variant::String() ) {
        return $this->toString();
    }
    elsif( $type == Qt::Variant::StringList() ) {
        return $this->toStringList();
    }
    elsif( $type == Qt::Variant::TextFormat() ) {
        return Qt::qVariantValue(Qt::TextFormat(), $this);
    }
    elsif( $type == Qt::Variant::TextLength() ) {
        return Qt::qVariantValue(Qt::TextLength(), $this);
    }
    elsif( $type == Qt::Variant::Time() ) {
        return $this->toTime();
    }
    elsif( $type == Qt::Variant::UInt() ) {
        return $this->toUInt();
    }
    elsif( $type == Qt::Variant::ULongLong() ) {
        return $this->toULongLong();
    }
    elsif( $type == Qt::Variant::Url() ) {
        return $this->toUrl();
    }
    else {
        return Qt::qVariantValue(undef, $this);
    }
});

sub String {
    return bless \shift, 'Qt::String';
}

sub CString {
    return bless \shift, 'Qt::CString';
}

sub Int {
    return bless \shift, 'Qt::Int';
}

sub Uint {
    return bless \shift, 'Qt::Uint';
}

sub Bool {
    return bless \shift, 'Qt::Bool';
}

sub Short {
    return bless \shift, 'Qt::Short';
}

sub Ushort {
    return bless \shift, 'Qt::Ushort';
}

sub Uchar {
    return bless \shift, 'Qt::Uchar';
}

1;

=begin

=head1 NAME

Qt - Perl bindings for the Qt version 4 library

=head1 SYNOPSIS

  use Qt;

=head1 DESCRIPTION

This module is a port of the PerlQt3 package to work with Qt version 4.

=head2 EXPORT

None by default.

=head1 SEE ALSO

The existing Qt documentation is very complete.  Use it for your reference.

Get the project's current version at http://code.google.com/p/perlqt4/

=head1 AUTHOR

Chris Burel, E<lt>chrisburel@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2008 by Chris Burel

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.8 or,
at your option, any later version of Perl 5 you may have available.

=cut

# vim:ts=4:sw=4:et:sta

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

sub argmatch {
    my ( $methodIds, $args, $argNum ) = @_;
    my %match;

    my $argType = getSVt( $args->[$argNum] );

    my $explicitType = 0;
               #index into methodId array
    foreach my $methodIdIdx ( 0..$#{$methodIds} ) {
        my $methodId = $methodIds->[$methodIdIdx];
        my $typeName = getTypeNameOfArg( $methodId, $argNum );
        # warn "check $typeName vs $argType ($args->[$argNum])\n";
        #ints and bools
        if ( $argType eq 'i' ) {
            if( $typeName =~ m/^(?:bool|(?:(?:un)?signed )?(?:int|long)|uint)[*&]?$/ ) {
                $match{$methodId} = [0,$methodIdIdx];
            }
        }
        # floats and doubles
        elsif ( $argType eq 'n' ) {
            if( $typeName =~ m/^(?:float|double)$/ ) {
                $match{$methodId} = [0,$methodIdIdx];
            }
        }
        # enums
        elsif ( $argType eq 'e' ) {
            my $refName = ref $args->[$argNum];
            if( $typeName =~ m/^$refName[s]?$/ ) {
                $match{$methodId} = [0,$methodIdIdx];
            }
        }
        # strings
        elsif ( $argType eq 's' ) {
            if( $typeName =~ m/^(?:(?:const )?u?char\*|(?:const )?(?:(QString)|QByteArray)[\*&]?)$/ ) {
                $match{$methodId} = [0,$methodIdIdx];
            }
        }
        # arrays
        elsif ( $argType eq 'a' ) {
            next unless defined $arrayTypes{$typeName};
            my @subArgTypes = uniq( map{ getSVt( $_ ) } @{$args->[$argNum]} );
            my @validTypes = @{$arrayTypes{$typeName}->{value}};
            my $good = 1;
            foreach my $subArgType ( @subArgTypes ) {
                if ( !grep{ $_ eq $subArgType } @validTypes ) {
                    $good = 0;
                    last;
                }
            }
            if( $good ) {
                $match{$methodId} = [0,$methodIdIdx];
            }
        }
        elsif ( $argType eq 'r' or $argType eq 'U' ) {
            $match{$methodId} = [0,$methodIdIdx];
        }
        elsif ( $argType eq 'Qt::String' ) {
            # This type exists only to resolve ambiguous method calls, so we
            # can return here.
            if( $typeName =~m/^(?:const )?QString[\*&]?$/ ) {
                return $methodId;
            }
            else {
                $explicitType = 1;
            }
        }
        elsif ( $argType eq 'Qt::CString' ) {
            # This type exists only to resolve ambiguous method calls, so we
            # can return here.
            if( $typeName =~m/^(?:const )?char ?\*[\*&]?$/ ) {
                return $methodId;
            }
            else {
                $explicitType = 1;
            }
        }
        elsif ( $argType eq 'Qt::Int' ) {
            # This type exists only to resolve ambiguous method calls, so we
            # can return here.
            if( $typeName =~ m/^int[\*&]?$/ ) {
                return $methodId;
            }
            else {
                $explicitType = 1;
            }
        }
        elsif ( $argType eq 'Qt::Uint' ) {
            # This type exists only to resolve ambiguous method calls, so we
            # can return here.
            if( $typeName =~ m/^unsigned int[\*&]?$/ ) {
                return $methodId;
            }
            else {
                $explicitType = 1;
            }
        }
        elsif ( $argType eq 'Qt::Bool' ) {
            # This type exists only to resolve ambiguous method calls, so we
            # can return here.
            if( $typeName eq 'bool' ) {
                return $methodId;
            }
            else {
                $explicitType = 1;
            }
        }
        elsif ( $argType eq 'Qt::Short' ) {
            if( $typeName =~ m/^short[\*&]?$/ ) {
                return $methodId;
            }
            else {
                $explicitType = 1;
            }
        }
        elsif ( $argType eq 'Qt::Ushort' ) {
            if( $typeName =~ m/^unsigned short[\*&]?$/ ) {
                return $methodId;
            }
            else {
                $explicitType = 1;
            }
        }
        elsif ( $argType eq 'Qt::Uchar' ) {
            if( $typeName =~ m/^u(?=nsigned )?char[\*&]?$/ ) {
                return $methodId;
            }
            else {
                $explicitType = 1;
            }
        }
        # objects
        else {
            # Optional const, some words, optional & or *.  Note ?: does not
            # make a backreference, (\w*) is the only thing actually captured.
            $typeName =~ s/^(?:const\s+)?(\w*)[&*]?$/$1/g;
            my $isa = classIsa( $argType, $typeName );
            if ( $isa != -1 ) {
                $match{$methodId} = [-$isa, $methodIdIdx];
            }
        }
    }

    if ( !%match && $explicitType ) {
        warn "no match";
        return -1;
    }

    # warn "matched ", scalar(keys %match), " possibilities\n";
    return sort { $match{$b}[0] <=> $match{$a}[0] or $match{$a}[1] <=> $match{$b}[1] } keys %match;
}

sub dumpArgs {
    return join ', ', map{
        my $refName = ref $_;
        $refName =~ s/^ *//;
        if($refName) {
            $refName;
        }
        else {
            $_;
        }
    } @_;
}

sub dumpCandidates {
    my ( $classname, $methodname, $methodIds ) = @_;
    my @methods;
    foreach my $id ( @{$methodIds} ) {
        my $numArgs = getNumArgs( $id );
        my $method = "$id\: $classname\::$methodname( ";
        $method .= join ', ', map{ getTypeNameOfArg( $id, $_ ) } ( 0..$numArgs-1 );
        $method .= " )";
        push @methods, $method;
    }
    return @methods;
}

my $HAS_METHOD = sub {
    my ($what) = @_;
    defined &{"$what"} and return(\&{"$what"});
};

sub install_autoload {
    my ($where) = @_;

    our $AUTOLOAD;
    $SET->("$where\::VERSION", Qt->VERSION);

    # TODO install a can() too

    $ISUB->("$where\::AUTOLOAD", sub {
        (my $method = $AUTOLOAD) =~ s/(.*):://;
        my $package = $1;
        DEBUG autoload => "autoloading $where for ($package) $method";

        { no strict 'refs'; delete ${"$where\::"}{AUTOLOAD}; }
        populate_class($where);
        if(my $sub = $HAS_METHOD->("$where\::$method")) {
            goto $sub;
        }
        elsif(my $autosub = $where->can('AUTOLOAD')) {
            # TODO that's actually in parent
            DEBUG autoload => "try parent autoload";
            goto $autosub;
        }
        else {
            Carp::croak("Can't locate object method ".
                qq{"$method" via package "$package"}
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
    my $class = shift;
    my $method = shift;
    my $id_list = shift;

    my $class_id = find_class_id($class);
    my ($id, $what) = getSmokeMethodId(@_,
        $class_id, $method, $classId2class{$class_id}
    );
    return($id);
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
    # TODO check a single id's signature though
    my $id = @$id_list > 1 ?
        resolver($class, $method, $id_list, @_) : $id_list->[0];

    unshift(@_, $id, $self);
    DEBUG calls => "call $class\::$method() as ",
        join(',', map({defined($_) ? $_ : '*undef*'} @_));
    goto &call_smoke;
}

# replace c++ package_classId() function
# Depth-first search of @ISA for a core package.
sub find_class_id {
    my ($package) = @_;

    return $package2classId{$package}
        if(exists $package2classId{$package});

    my $isa = $A->($package . '::ISA');
    foreach my $entry (@$isa) {
        my @got = find_class_id($entry);
        return($got[0]) if(@got);
    }
    return();
}

# Args: @_: the args to the method being called
#       $classname: the c++ class being called
#       $methodname: the c++ method name being called
#       $classId: the smoke class Id of $classname
# Returns: A disambiguated method id
# Desc: Examines the arguments of the method call to build a method signature.
#       From that signature, it determines the appropriate method id.
sub getSmokeMethodId {
    my $classname = pop;
    my $methodname = pop;
    my $classId = pop;

    DEBUG calls =>
        "getSmokeMethodId(..., $classname, $methodname, $classId)\n";

    # Loop over the arguments to determine the type of args
    my @mungedMethods = ( $methodname );
    foreach my $arg ( @_ ) {
        if (!defined $arg) {
            # An undefined value requires a search for each type of argument
            @mungedMethods = map { $_ . '#', $_ . '?', $_ . '$' } @mungedMethods;
        } elsif(isObject($arg)) {
            @mungedMethods = map { $_ . '#' } @mungedMethods;
        } elsif((ref $arg) =~ m/HASH|ARRAY/) {
            @mungedMethods = map { $_ . '?' } @mungedMethods;
        } else {
            @mungedMethods = map { $_ . '$' } @mungedMethods;
        }
    }
    DEBUG calls_verbose => "lookup $classname @mungedMethods";
    my @methodIds = map { findMethod( $classname, $_ ) } @mungedMethods;

    my $cacheLookup = 1;

    # If we didn't get any methodIds, look for alternatives, and try convert
    # the arguments we have to the kind this method call wants
    if (!@methodIds) {
        my @altMethod = findAnyPossibleMethod( $classname, $methodname, @_ );

        # Only try this if there's only one possible alternative
        if ( @altMethod == 1 ) {
            my $altMethod = $altMethod[0];
            foreach my $argId ( 0..$#_ ) {
                my $wantType = getTypeNameOfArg( $altMethod, $argId );
                $wantType =~ s/^const\s+//;
                $wantType =~ s/(?<=\w)[&*]$//g;
                $wantType = normalize_classname( $wantType );
                no strict qw( refs );
                $_[$argId] = $wantType->( $_[$argId] );
                use strict;
            }
            my( $methodId ) = getSmokeMethodId( @_, $classId, $methodname, $classname );
            # Don't cache this lookup.
            return $methodId, 0;
        }
    }

    # If we got more than 1 method id, resolve it
    if (@methodIds > 1) {
        foreach my $argNum (0..$#_) {
            my @matching = argmatch( \@methodIds, \@_, $argNum );
            if (@matching) {
                if ($matching[0] == -1) {
                    @methodIds = ();
                }
                else {
                    @methodIds = @matching;
                }
            }
        }

        # Look for the user-defined signature
        if ( @methodIds > 1 && defined $ambiguousSignature ) {
            foreach my $methodId ( @methodIds ) {
                my ($signature) = dumpCandidates( $classname, $methodname, [$methodId] );
                if ( $signature eq $ambiguousSignature ) {
                    @methodIds = ($methodId);
                    $ambiguousSignature = undef;
                    last;
                }
            }
        }

        # If we still have more than 1 match, use the first one.
        if ( @methodIds > 1 ) {
            my $msg = "--- Ambiguous method ${classname}::$methodname";
            $msg .= "Candidates are:\n\t";
            $msg .= join "\n\t", dumpCandidates( $classname, $methodname, \@methodIds );
            $msg .= "\nChoosing first one...\n";
            die $msg;
            @methodIds = $methodIds[0];

            # Since a call to this same method with different args may resolve
            # differently, don't cache this lookup
            $cacheLookup = 0;
        }
    }
    elsif ( @methodIds == 1 and @_ ) {
        # We have one match and arguments.  We need to make sure our input
        # arguments match what the method is expecting.  Clear methodIds if
        # args don't match
        if (!objmatch($methodIds[0], \@_)) {
            my $errStr = '--- Arguments for method call ' .
                "$classname\::$methodname did not match C++ method ".
                "signature,";
            $errStr .= "Method call was:\n\t";
            $errStr .= "$classname\::$methodname( " . dumpArgs(@_) . " )\n";
            $errStr .= "C++ signature is:\n\t";
            $errStr .= (dumpCandidates( $classname, $methodname, \@methodIds ))[0] . "\n";
            @methodIds = ();
            print STDERR $errStr and die;
        }
    }

    if ( !@methodIds ) {
        @methodIds = findAnyPossibleMethod( $classname, $methodname, @_ );
        if( @methodIds ) {
            die reportAlternativeMethods( $classname, $methodname, \@methodIds, @_ );
        }
        else {
            die reportNoMethodFound( $classname, $methodname, @_ );
        }
    }

    return $methodIds[0], $cacheLookup;
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

# Does the method exist, but the user just gave bad args?
sub findAnyPossibleMethod {
    my $classname = shift;
    my $methodname = shift;

    my @last = '';
    my @mungedMethods = ( $methodname );
    # 14 is the max number of args, but that's way too many permutations.
    # Keep it short.
    foreach ( 0..7 ) { 
        @last = permateMungedMethods( ['$', '?', '#'], @last );
        push @mungedMethods, map{ $methodname . $_ } @last;
    }

    return map { findMethod( $classname, $_ ) } @mungedMethods;
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

    # The root of the tree will be Qt::base, so a call to
    # $className::new() redirects there.
    @isa = ('Qt::base') unless @isa;
    @{$A->($perlClassName.'::ISA')} =  @isa;

    { # pretend we loaded a .pm file
        (my $pm = $perlClassName . '.pm') =~ s{::}{/}g;
        $INC{$pm} = __FILE__;
    }

    install_autoload($perlClassName);

    # Define overloaded operators
    # @{$A->(" $perlClassName\::ISA")} = ('Qt::base::_overload');

    # foreach my $sp ('', ' ') {
    #     my $where = $sp . $perlClassName;
    #     installautoload($where);
    # }

    # $ISUB->("$perlClassName\::NEW", sub {
    #     # Removes $perlClassName from the front of @_
    #     my $perlClassName = shift;

    #     # If we have a cxx classname that's in some other namespace, like
    #     # QTextEdit::ExtraSelection, remove the first bit.
    #     $cxxClassName =~ s/.*://;
    #     $Qt::AutoLoad::AUTOLOAD = "$perlClassName\::$cxxClassName";
    #     my $autoload = \&{"$perlClassName\::AUTOLOAD"};
    #     setThis( bless &$autoload, " $perlClassName" );
    # }) unless(defined &{"$perlClassName\::NEW"});

    # Make the constructor subroutine
    # $ISUB->($perlClassName, sub {
    #     # Adds $perlClassName to the front of @_
    #     $perlClassName->new(@_);
    # }) unless(defined &{$perlClassName});
}

sub permateMungedMethods {
    my $sigils = shift;
    my @output;
    while( defined( my $input = shift ) ) {
        push @output, map{ $input . $_ } @{$sigils};
    }
    return @output;
}

sub reportAlternativeMethods {
    my $classname = shift;
    my $methodname = shift;
    my $methodIds = shift;
    # @_ now equals the original argument array of the method call
    my $errStr = '--- Arguments for method call ' .
        "$classname\::$methodname did not match any known C++ method ".
        "signature,";
    $errStr .= "Method call was:\n\t";
    $errStr .= "$classname\::$methodname( " . dumpArgs(@_) . " )" .
        Carp::shortmess();
    $errStr .= "Possible candidates:\n\t";
    $errStr .= join( "\n\t", dumpCandidates( $classname, $methodname, $methodIds ) ) . "\n";
    return $errStr;
}

sub reportNoMethodFound {
    my $classname = shift;
    my $methodname = shift;
    # @_ now equals the original argument array of the method call

    my $errStr = '--- Error: Method does not exist or not provided by this ' .
        "binding:\n";
    $errStr .= "$classname\::$methodname(),\n";
    return $errStr;
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

sub objmatch {
    my ( $methodname, $args ) = @_;

    DEBUG calls => "running objmatch on $methodname()";
    foreach my $i ( 0..$#$args ) {
        # Compare our actual args to what the method expects
        my $argtype = getSVt($$args[$i]);

        # argtype will be only 1 char if it is not an object. If that's the
        # case, don't do any checks.
        next if length $argtype == 1;

        my $typename = getTypeNameOfArg( $methodname, $i );

        # We don't care about const or [&*]
        $typename =~ s/^const\s+//;
        $typename =~ s/(?<=\w)[&*]$//g;

        return 0 if classIsa($argtype, $typename) == -1;
    }
    return 1;
}

sub Qt::CoreApplication::NEW {
    Carp::croak("bah");
    my $class = shift;
    my $argv = shift;
    unshift @$argv, $0;
    my $count = scalar @$argv;
    my $retval = Qt::CoreApplication::QCoreApplication( $count, $argv );
    bless( $retval, " $class" );
    setThis( $retval );
    setQApp( $retval );
    shift @$argv;
}

sub Qt::Application::new {
    my ($class, $argv) = @_;

    my @args = ($0, @$argv);
    my $retval = $class->__new(scalar(@args), \@args);
    Qt::setQApp($retval);
    return($retval);
}

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
    if( ref $var ) {
        if ( $class->isa( 'Qt::base' ) ) {
            $class = " $class";
        }
        return bless( $var, $class );
    }
    else {
        return bless( \$var, $class );
    }
}

sub import { goto &Exporter::import }

sub setSignature {
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

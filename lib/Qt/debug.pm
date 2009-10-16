package Qt::debug;

use warnings;
use strict;
use Carp;

require Exporter;
our @EXPORT = qw(DEBUG);

our %channel = (
    ambiguous => 0x01,
    autoload  => 0x02,
    calls     => 0x04,
    gc        => 0x08,
    virtual   => 0x10,
    verbose   => 0x20,
    signals   => 0x40,
    slots     => 0x80,
    marshall  => 0x100,
    'all' => 0xffff
);

sub dumpMetaMethods {
    my ( $object ) = @_;

    # Did we get an object in, or just a class name?
    my $className = ref $object ? ref $object : $object;
    $className =~ s/^ *//;
    my $meta = Qt::_internal::getMetaObject( $className );

    if ( $meta->methodCount() ) {
        print join '', 'Methods for ', $meta->className(), ":\n"
    }
    else {
        print join '', 'No methods for ', $meta->className(), ".\n";
    }
    foreach my $index ( 0..$meta->methodCount()-1 ) {
        my $metaMethod = $meta->method($index);
        print $metaMethod->typeName . ' ' if $metaMethod->typeName;
        print $metaMethod->signature() . "\n";
    }
    print "\n";

    if ( $meta->classInfoCount() ) {
        print join '', 'Class info for ', $meta->className(), ":\n"
    }
    else {
        print join '', 'No class info for ', $meta->className(), ".\n";
    }
    foreach my $index ( 0..$meta->classInfoCount()-1 ) {
        my $classInfo = $meta->classInfo($index);
        print join '', '\'', $classInfo->name, '\' => \'', $classInfo->value, "'\n";
    }
    print "\n";
}

sub import {
    my $package = shift;

    unless(@_) {
      unshift(@_, $package);
      goto &Exporter::import;
    }

    require Qt;

    my $db = (@_)? 0x0000 : (0x01|0x80);
    my $usage = 0;
    for my $ch(@_) {
        if( exists $channel{$ch}) {
             $db |= $channel{$ch};
        } else {
             warn "Unknown debugging channel: $ch\n";
             $usage++;
        }
    }
    Qt::_internal::setDebug($db);    
    print "Available channels: \n\t".
          join("\n\t", sort keys %channel).
          "\n" if $usage;
}

sub unimport {
    Qt::_internal::setDebug(0);    
}

sub DEBUG (@) {
  my ($flags, @msg) = @_;

  my $db_flag = 0;
  foreach my $flag (split(/\|/, $flags)) {
    croak("no such channel '$flag'") unless(exists $channel{$flag});
    $db_flag |= $channel{$flag};
  }

  return unless($db_flag & Qt::_internal::getDebug());

  # my $x = $Carp::Verbose;
  if($msg[-1] =~ m/\n$/ and not $Carp::Verbose) {
    warn @msg;
  }
  else {
    local $Carp::CarpLevel = 1;
    Carp::carp(@msg);
  }
}

1;

#!/usr/bin/perl

package Pong;

use strict;
use warnings;

use Qt;
use Qt::isa qw( Qt::Object );
use Qt::slots
    'QString ping' => ['QString'];

sub NEW {
    shift->SUPER::NEW(@_);
}

sub ping {
    my ( $arg ) = @_;
    Qt::MetaObject::invokeMethod(Qt::CoreApplication::instance(), 'quit');
    return "ping(\"$arg\") got called";
}

package main;

use strict;
use warnings;
use blib;

use Qt;
use Pong;
use PingCommon qw( SERVICE_NAME );

sub main {
    my $app = Qt::Application(\@ARGV);

    if (!Qt::DBusConnection::sessionBus()->isConnected()) {
        die "Cannot connect to the D-BUS session bus.\n" .
                "To start it, run:\n" .
                "\teval `dbus-launch --auto-syntax`\n";
    }

    if (!Qt::DBusConnection::sessionBus()->registerService(SERVICE_NAME)) {
        die Qt::DBusConnection::sessionBus()->lastError()->message();
        exit(1);
    }

    my $pong = Pong();
    Qt::DBusConnection::sessionBus()->registerObject('/', $pong, Qt::DBusConnection::ExportAllSlots());
    
    exit $app->exec();
}

main();

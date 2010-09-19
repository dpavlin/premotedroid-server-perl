#!/usr/bin/perl
use warnings;
use strict;

use IO::Socket::INET;
use Data::Dump qw(dump);

my $sock = IO::Socket::INET->new(
	Listen    => 5,
#	LocalAddr => 'localhost',
	LocalPort => 64788,
	Proto     => 'tcp',
	Reuse     => 1,
) || die $!;

warn "listen on ", dump $sock->sockaddr, $sock->sockport;

sub readUTF {
	my $client = shift;
	read $client, my $len, 2;
	$len = unpack( 'n', $len );
	read $client, my $utf, $len;
	warn "## readUTF $len [$utf]";
	return $utf;
}

# from PRemoteDroid Protocol/src/org/pierre/remotedroid/protocol/action/PRemoteDroidAction.java
use constant MOUSE_MOVE => 0;
use constant MOUSE_CLICK => 1;
use constant MOUSE_WHEEL => 2;
use constant KEYBOARD => 3;
use constant AUTHENTIFICATION => 4;
use constant AUTHENTIFICATION_RESPONSE => 5;
use constant SCREEN_CAPTURE_REQUEST => 6;
use constant SCREEN_CAPTURE_RESPONSE => 7;
use constant FILE_EXPLORE_REQUEST => 8;
use constant FILE_EXPLORE_RESPONSE => 9;

open(my $xdo, '|-', 'xdotool -') || die $!;
select($xdo); $|=1;

my $keysyms = {
	-1 => 'BackSpace',
	10 => 'Return',
};

while ( my $client = $sock->accept() ) {

	warn "connect from ", dump $client->peeraddr, $client->peerport;

	while ( read $client, my $command, 1 ) {
		$command = ord $command;
		warn "# command: $command\n";
		if ( $command == MOUSE_MOVE ) {
			read $client, my $move, 4;
			my ( $x, $y ) = unpack 's>s>', $move; # big-endian 16 bit
			warn "MOVE $x $y\n";
			print $xdo "mousemove_relative -- $x $y\n";
		} elsif ( $command == MOUSE_CLICK ) {
			read $client, my $b, 2;
			my ( $button, $state ) = unpack 'cc', $b;
			warn "MOUSE_CLICK $button $state\n";
			print $xdo 'mouse' . ( $state ? 'down' : 'up' ) . ' ' . $button . "\n";
		} elsif ( $command == MOUSE_WHEEL ) {
			read $client, my $amount, 1;
			$amount = unpack 'c', $amount;
			warn "MOUSE_WHEEL $amount\n";
			print $xdo 'click ' . ( $amount > 0 ? 4 : 5 ) . "\n" foreach ( 1 .. abs($amount) );
		} elsif ( $command == AUTHENTIFICATION ) {
			my $auth = readUTF $client;
			warn "AUTHENTIFICATION [$auth]\n";
			print $client pack 'cc', AUTHENTIFICATION_RESPONSE, 1; # FIXME anything goes
		} elsif ( $command == KEYBOARD ) {
			read $client, my $unicode, 4;
			my $key = unpack 'l>', $unicode;
			my $command = 'type';
			if ( defined $keysyms->{$key} ) {
				$key = $keysyms->{$key};
				$command = 'key';
			} else {
				$key = chr($key);
				$command = 'key' if $key =~ m/^\w$/;
			}
			warn uc($command)," $key\n";
			print $xdo "$command '$key'\n";
		} else {
			die "UNSUPPORTED";
		}
	}

	warn "client disconnected\n";

}

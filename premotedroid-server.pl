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

while ( my $client = $sock->accept() ) {

	warn "connect from ", dump $client->peeraddr, $client->peerport;

	while ( read $client, my $command, 1 ) {
		$command = ord $command;
		warn "# command: $command\n";
		if ( $command == 4 ) {
			read $client, my $len, 2;
			read $client, my $auth, unpack( 'n', $len );
			warn "AUTHENTIFICATION $len $auth\n";
		} else {
			die "UNSUPPORTED";
		}
	}

	warn "client disconnected\n";

}

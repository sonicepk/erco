#!/usr/bin/perl
# vim:set sw=4 ts=4 sts=4 ft=perl expandtab:
use Mojo::Base -base;

use Mojo::UserAgent;
use Mojo::IOLoop;
use Term::ReadLine;

select STDOUT; $| = 1;

my $history_file = $ENV{HOME}.'/.exabgp_wsclient_history';
my $ua           = Mojo::UserAgent->new;
my @history;

#################
# Create console
#################
my $term = Term::ReadLine->new('ws-client');

## Autocompletion
### Dictionnary
my @words = ('help', 'exit', 'quit', 'help', 'version', 'reload', 'restart', 'shutdown', 'announce', 'withdraw', 'show');
my %complement = (
    announce => ['route', 'flow'],
    withdraw => ['route', 'flow'],
    show     => ['neighbors', 'routes']
);

### Use dictionnary
if (my $attr = $term->Attribs) {
    $attr->{completion_function} = \&_complete_word;
}

## Load history
if (-f $history_file) {
    open my $hist, '<', $history_file or die "Unable to open $history_file: $!";
    while (defined(my $line = <$hist>)) {
        chomp $line;
        _addtohistory($line);
        $term->addhistory($line);
    }
    close $hist;
}

my $prompt = '> ';

################
# Launch console
################
print <<EOF;
Welcome on exabgp-ws-client.
Type 'help' to get some help, 'exit' or 'quit' to exit.
Easy, isn't it?
EOF

while (defined(my $command = $term->readline($prompt))) {
    chomp $command;
    _addtohistory($command) unless ($command eq 'exit' || $command eq 'quit');

    if ($command eq 'help') {
        _help();
    } elsif ($command eq 'exit' || $command eq 'quit') {
        _exit();
    } else {
        $ua->websocket('ws://127.0.0.1:3005/' => sub {
            my ($ua, $ws) = @_;
            say 'WebSocket handshake failed!' and return unless $ws->is_websocket;
            $ws->send($command);
            $ws->on(
                message => sub {
                    my ($ws, $msg) = @_;
                    say $msg;
                }
            );
        });
        Mojo::IOLoop->start;
    }
}
say '';
_exit();

# Internal functions
sub _help {
    say <<EOF;

(c) 2015 Luc Didry <luc\@didry.org>
This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

This program is just a way to manually enter commands using websockets.
Routes and flows syntax are parsed like normal configuration.

Commands:
    - quit|exit closes the client
    - version   returns the version of exabgp
    - reload    reloads the configuration - cause exabgp to forget all routes learned via external processes
    - restart   reloads the configuration and bounce all BGP session
    - shutdown  politely terminates all session and exit

WARNING : The result of the following commands will depend on the route, it could even cause the BGP session to drop.
          It could even cause the BGP session to drop, for example if you send flow routes to a router which does not support it.

The route will be sent to ALL the peers (there is no way to filter the announcement yet)

    - annouce route
      The multi-line syntax is currently not supported
      example: announce route 1.2.3.4 next-hop 5.6.7.8
    - withdraw route
      example: withdraw route (example: withdraw route 1.2.3.4 next-hop 5.6.7.8)
    - announce flow
      Exabgp does not have a single line flow syntax so you must use the multiline version indicating newlines with \\n
      example: announce flow route {\\n match {\\n source 10.0.0.1/32;\\n destination 1.2.3.4/32;\\n }\\n then {\\n discard;\\n }\\n }\\n
    - withdraw flow
      Exabgp does not have a single line flow syntax so you must use the multiline version indicating newlines with \\n
      example: withdraw flow route {\\n match {\\n source 10.0.0.1/32;\\n destination 1.2.3.4/32;\\n }\\n then {\\n discard;\\n }\\n }\\n

SHOW COMMANDS SHOULD NOT BE USED IN PRODUCTION AS THEY HALT THE BGP ROUTE PROCESSING
AND CAN RESULT IN BGP PEERING SESSION DROPPING - You have been warned

    - show neighbors displays the neighbor configured
    - show routes    displays routes which have been announced

EOF
}

sub _complete_word {
    my ($text, $line, $start) = @_;
    if ($start == 0) {
        return grep(/^$text/, @words);
    } else {
        my @a = split(' ', $line);
        $a[1] = '' unless (defined($a[1]));
        my @b = grep(/^$a[1]/, @{$complement{$a[0]}});
        if (scalar(@b) == 1) {
            return () if ($b[0] eq $a[1]);
        }
        return @b;
    }
}

sub _addtohistory {
    my $line = shift;
    push @history, $line;
    while (scalar(@history) > 100) {
        shift @history;
    }
}

sub _exit {
    open my $hist, '>', $history_file or die "Unable to open $history_file: $!";
    print $hist join("\n", @history);
    close $hist;
    print "\n", 'Good bye !', "\n";
    exit 0;
}

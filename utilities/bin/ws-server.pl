#!/usr/bin/env perl
use Mojolicious::Lite;
use Time::HiRes qw(usleep);
use IO::Handle;

# Ignore Control C
# allow exabgp to send us a SIGTERM when it is time
$SIG{'INT'} = sub {};

select STDOUT; $| = 1;

my $io = IO::Handle->new();

websocket '/' => sub {
    my $c = shift;

    $c->inactivity_timeout(300);
    $c->on(
        message => sub {
            my ($ws, $command) = @_;

            say $command;

            if ($io->fdopen(fileno(STDIN),"r")) {
                $io->blocking(0);
                if (defined(my $msg = $io->getline)) {
                    chomp $msg;
                    $c->app->log->info($msg);
                    $ws->send($msg);
                } else {
                    usleep 500;
                }
                while (defined(my $msg = $io->getline)) {;
                    chomp $msg;
                    $c->app->log->info($msg);
                    $ws->send($msg);

                    # Be sure it's the end of the answer
                    usleep 500 if ($io->eof);
                }
                $io->close;
            }
            $ws->finish;
        }
    );
};

app->start;

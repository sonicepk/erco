# vim:set sw=4 ts=4 sts=4 ft=perl expandtab:
package Erco::Controller::API::Exabgp;
use Mojo::Base 'Mojolicious::Controller';
use Mojo::JSON qw(true false encode_json);
use Mojo::IOLoop;
use Mojo::UserAgent;

# Gives the list of available commands
sub commands {
    my $c = shift;

    $c->render(
        json => $c->config('commands')
    );
}

# Exec exabgp commands
sub command {
    my $c = shift;
    my $a = $c->param('action');

    my $msg = {
        success => false,
        msg     => ''
    };

    # Special case: this one doesn't have to be configured
    if ($a eq 'reload') {
        my $delay = Mojo::IOLoop->delay;

        $delay->on(finish => sub {
            my $delay = shift;
            my $result = $_[0];
            if ($result->{success}) {
                my $running = $c->is_exa_running;

                # Give time to exabgp to reload, just in case
                unless ($running) {
                    sleep 1;
                    $running = $c->is_exa_running;
                }
                if ($running) {
                    $msg->{success} = true;
                    $msg->{msg}     = $c->l('Exabgp has been successfully reloaded.');
                } else {
                    $msg->{msg} = $c->l('Exabgp has been reloaded but is not running.');
                }
            } else {
                $msg->{msg} = $result->{msg};
            }

            $c->render(
                json => $msg
            );
        });
        $c->exaconf->reload_exabgp($delay->begin(0));
        $delay->wait;
    } else {
        chomp $a;

        # Is the command authorized?
        if (grep (/^$a$/, @{$c->config('commands')})) {
            my @msgs;

            $c->render_later;
            my $ua = $c->ua;
            $ua->inactivity_timeout(300);
            $ua->websocket('ws://127.0.0.1:3005/' => sub {
                my ($ua, $ws) = @_;
                unless ($ws->is_websocket) {
                    $msg->{msg} = $c->l('WebSocket handshake failed!');
                    return $c->render(
                        json => $msg
                    );
                }

                $ws->send($a);
                $ws->on(
                    message => sub {
                        my ($ws, $msg) = @_;
                        push @msgs, $msg;
                    }
                );
                $ws->on(
                    finish => sub {
                        $msg->{success} = true;
                        $msg->{msg}     = join("\n", @msgs);
                        $c->render(
                            json => $msg
                        );
                    }
                );
            });
        } else {
            $c->app->log->info(sprintf('IP %s tried to launch the following unauthorized command: %s', $c->remote_addr, $a));
            $msg->{msg}     = $c->l('You tried to launch an unauthorized command. Contact an administrator.');
        }
    }
}

# Gives Exabgp status (running or not?)
sub status {
    my $c = shift;

    # Websocket part
    if ($c->tx->is_websocket) {
        $c->debug('Client connected');

        # Let's start a loop to keep client up to date
        my $loop = Mojo::IOLoop->singleton;
        $loop->stream($c->tx->connection)->timeout(10);

        $loop->recurring(1 => sub {
            if (defined($c->tx)) {
                $c->app->log->info('PID file ('.$c->config('exabgp_pid_file').') is missing or not readable!') unless (-r $c->config('exabgp_pid_file'));
                $c->tx->send(
                    {
                        json => {
                            file_missing => (-r $c->config('exabgp_pid_file')) ? false : true,
                            running      => ($c->is_exa_running) ? true : false
                        }
                    }
                );
            }
        });

        $c->on(
            finish => sub {
                $c->debug('Client disconnected');
            }
        );
    } else { # Ajax fallback part (the client is polling)
        $c->app->log->info('PID file ('.$c->config('exabgp_pid_file').') is missing or not readable!') unless (-r $c->config('exabgp_pid_file'));
        $c->render(
            json => {
                file_missing => (-r $c->config('exabgp_pid_file')) ? false : true,
                running      => ($c->is_exa_running) ? true : false
            }
        );
    }
}

1;

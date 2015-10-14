# vim:set sw=4 ts=4 sts=4 ft=perl expandtab:
package Erco::ExaConf;
use Mojo::Base -base;
use Mojo::JSON qw(encode_json decode_json);
use Mojo::Date;
use Mojo::Collection;
use Erco::ExaConf::Entries;
use Erco::ExaConf::Entry;
use NetAddr::IP;
use Carp;

has 'app';
has 'file';
has 'entries' => sub { Erco::ExaConf::Entries->new(); };
has 'route';

# Create object
# ! file argument is mandatory
sub new {
    my $c = shift;

    $c = $c->SUPER::new(@_);

    $c->_parse();

    return $c;
}

# Write configuration to file
sub write {
    my $c = shift;

    my $file = $c->file;

    # Undefined file?
    if (!defined($file)) {
        $c->app->log->info('Can\'t parse: no configuration file');
        carp 'Can\'t parse: no configuration file';
        return undef;
    } elsif (!(-w $file)) { # Readable file?
        $c->app->log->info('Can\'t parse '.$file.': file does not exist or is not writable');
        carp 'Can\'t parse '.$file.': file does not exist or is not writable';
        return undef;
    } else {
        # Open for reading
        my $op_res = open my $fh, '<', $file;
        unless ($op_res) {
            carp 'Can\'t open '.$file.': '.$!;
            return undef;
        }

        my @a = <$fh>;
        close $fh;

        # Open for writing
        $op_res = open $fh, '>', $file;
        unless ($op_res) {
            carp 'Can\'t open '.$file.': '.$!;
            return undef;
        }

        # Let's write!
        my ($skip, $prefix) = (0, '');
        for my $line (@a) {
            chomp $line;
            if ($line =~ m/(\s*)#ERCO CONTROLLED PART/) {
                say $fh $line;
                $prefix = $1;
                $skip = 1;
                $c->entries->each(
                    sub {
                        my ($e, $num) = @_;
                        if (defined($e)) {
                            my $com = $e->communities->join(' ');
                            $com    = '['.$com.']' if ($e->communities->size > 1);

                            if ($e->local_pref ne '') {
                                say $fh $prefix.sprintf('route %s next-hop %s local-preference %s community %s;', $e->cidr, $e->next_hop, $e->local_pref, $com);
                            } else {
                                say $fh $prefix.sprintf('route %s next-hop %s community %s;', $e->cidr, $e->next_hop, $com);
                            }
                            my $msg = $prefix;
                            if (defined($e->modified_at)) {
                                $msg .= sprintf('#{"human_created_at":"%s", "human_modified_at":"%s", "created_at":%d, "modified_at":%d}', $e->human_created_at, $e->human_modified_at, $e->created_at, $e->modified_at);
                            } else {
                                $msg .= sprintf('#{"human_created_at":"%s", "created_at":%d}', $e->human_created_at, $e->created_at);
                            }
                            say $fh $msg;
                        }
                    }
                );
            } elsif (index($line, '#END OF ERCO CONTROLLED PART') > -1) { # We stop to fetch items
                $skip = 0;
            }
            say $fh $line unless ($skip);
        }
        close $fh;

        $c->reload_exabgp(sub {});

        return 1;
    }
}

sub reload_exabgp {
    my $c = shift;
    my $e = shift;

    my $result = {
        success => 0,
        msg     => ''
    };
    my $delay = Mojo::IOLoop->delay;
    $delay->on(finish => sub {
        my $delay = shift;
        $e->($result);
    });

    my $ua = $c->app->ua;
    $ua->inactivity_timeout(300);
    $ua->websocket('ws://127.0.0.1:3005/' => sub {
        my ($ua, $ws) = @_;
        my $end       = $delay->begin(0);
        unless ($ws->is_websocket) {
            $result->{msg} = $c->app->l('We tried to reload Exabgp but it failed (WebSocket handshake failed). Contact an administrator.');
            $end->($result);
        }

        $ws->send('reload');
        $ws->on(
            message => sub {
                my ($ws, $msg) = @_;
                if ($msg eq 'reload in progress') {
                    $result->{success} = 1;
                    $result->{msg}     = $c->app->l('Exabgp has been successfully reloaded.');
                }
            }
        );
        $ws->on(
            finish => sub {
                $end->($result);
            }
        );
    });
    $delay->wait;
}

sub _parse {
    my $c = shift;

    my $file = $c->file;

    # Undefined file?
    if (!defined($file)) {
        $c->app->log->info('Can\'t parse: no configuration file');
        carp 'Can\'t parse: no configuration file';
        return undef;
    } elsif (!(-r $file)) { # Readable file?
        $c->app->log->info('Can\'t parse '.$file.': file does not exist or is not readable');
        carp 'Can\'t parse '.$file.': file does not exist or is not readable';
        return undef;
    } else {
        # Open
        my $op_res = open my $fh, '<', $file;
        unless ($op_res) {
            carp 'Can\'t open '.$file.': '.$!;
            return undef;
        }

        my $have_controlled_part = 0;
        my ($i, $work, $get_info, $date, $entries, $entry, $duplicate) = (1, 0, 0, Mojo::Date->new, $c->entries, undef, 0);

        # Let's parse!
        while (my $line = <$fh>) {
            chomp $line;

            # We start to fetch items
            if (index($line, '#ERCO CONTROLLED PART') > -1) {
                $work                 = 1;
                $have_controlled_part = 1;
            } elsif (index($line, '#END OF ERCO CONTROLLED PART') > -1) { # We stop to fetch items
                $work = 0;
                $entry = undef;
            }

            if ($work) {
                # This is a real configuration line
                if ($line =~ m/route\s+(\S+)\s+next-hop\s+(\S+)(?:\s+local-preference\s+(\S+))?\s+community\s+(.+);/) {
                    my ($route, $next_hop, $local_pref, $community) = ($1, $2, $3, $4);
                    $local_pref = '' unless (defined($local_pref) && $c->app->config('local_pref'));

                    my $stop = 0;
                    # Check if the community is known (exists in configuration file)
                    my @communities;
                    if ($community =~ m/\[([^\]]+)\]/) {
                        @communities = split(' ', $1);
                    } else {
                        push @communities, $community;
                    }
                    for $community (@communities) {
                        if (!defined($c->app->config('communities')->{$community})) {
                            $stop = 1;
                            carp 'Unknown community: '.$community;
                        }
                    }
                    if (!defined($c->app->config('next_hops')->{$next_hop})) { # Check if the next hop is known (exists in configuration file)
                        $stop = 1;
                        carp 'Unknown next hop: '.$next_hop;
                    }
                    unless ($stop) {
                        # Does the entry already exists?
                        if (my $e = $entries->find_entry_by_cidr(new NetAddr::IP($route)->cidr)) {
                            push @{$e->communities}, @communities;
                            $duplicate = 1;
                        } else {
                            if ($get_info) {
                                $entry->id($i++);

                                $date->epoch(time);
                                $entry->created_at($date->epoch);
                                $entry->human_created_at($date->to_string);

                                push @{$entries}, $entry;
                                $get_info  = 0;
                            }
                            $entry = Erco::ExaConf::Entry->new(
                                cidr        => new NetAddr::IP($route)->cidr(),
                                next_hop    => $next_hop,
                                local_pref  => $local_pref,
                                communities => Mojo::Collection->new(@communities)
                            );
                            $get_info = 1;
                        }
                    }
                } elsif (index($line, '#{') > -1) { # This is Erco metadata
                    if (defined($entry)) {
                        $entry->id($i++);

                        $line      =~ s/^\s*#//;
                        my $struct = decode_json($line);

                        $date->epoch($struct->{created_at});
                        $entry->created_at($date->epoch);
                        $entry->human_created_at($date->to_string);

                        if (defined($struct->{modified_at})) {
                            $date->epoch($struct->{modified_at});
                            $entry->modified_at($date->epoch);
                            $entry->human_modified_at($date->to_string);
                        }

                        $entry->id($struct->{id}) if (defined($struct->{id}));

                        my $copy = $entry;

                        push @{$entries}, $copy;
                        $entry = undef;
                    } else {
                        unless ($duplicate) {
                            $c->app->log->warn('Got info but not related entry. This is not supposed to happen');
                            carp 'Got info but not related entry. This is not supposed to happen';
                        }
                    }
                    $get_info  = 0;
                }
            }
        }

        # Do we have an Erco controlled part?
        unless ($have_controlled_part) {
            $c->app->log->info('The exabgp configuration file does not have an Erco controlled part');
            die "\n".'The exabgp configuration file does not have an Erco controlled part';
        }

        # Be sure to have each community only one time for each per entry
        $entries->each(
            sub {
                my ($e, $num) = @_;
                $e->communities($e->communities->uniq);
            }
        );
        $c->entries($entries);

        return $entries;
    }
}

1;

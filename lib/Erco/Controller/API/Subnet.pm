# vim:set sw=4 ts=4 sts=4 ft=perl expandtab:
package Erco::Controller::API::Subnet;
use Mojo::Base 'Mojolicious::Controller';
use Mojo::JSON qw(true false);
use NetAddr::IP;

# Gives a list of entries
sub get {
    my $c   = shift;

    $c->render(
        json => $c->exaconf->entries->to_array,
    );
}

# Create a new entry
sub post {
    my $c           = shift;
    my $cidr        = $c->param('cidr');
    my $next_hop    = $c->param('next_hop');
    my $communities = $c->every_param('communities[]');
    my $net         = new NetAddr::IP($cidr);

    my ($success, $msg, $entry, $com_collection) = (0, undef, undef, Mojo::Collection->new());

    # Check if the client is sending a good community
    my $communities_check = 1;
    for my $com (@{$communities}) {
        if (!defined($c->config('communities')->{$com})) {
            $msg               = $c->l('"[_1]" is not a valid community (not declared in Erco configuration).', $com);
            $communities_check = 0;
            last;
        } else {
            push @{$com_collection}, $com;
        }
    }

    if ($communities_check) {
        # Check if the client is sending a good next hop
        if (!defined($c->config('next_hops')->{$next_hop})) {
            $msg     = $c->l('"[_1]" is not a valid next hop (not declared in Erco configuration).', $next_hop);
        } elsif ($net) { # If this is OK, the client has sent a real IP or network address
            my $exaconf = $c->exaconf;
            my $entries = $exaconf->entries;

            if ($entries->find_entry_by_cidr($net->cidr)) {
                $msg     = $c->l('"[_1]" is already announced.', $cidr);
            } else {
                my $max_id = $entries->max_id;
                my $date   = Mojo::Date->new(time);

                $entry = Erco::ExaConf::Entry->new(
                    cidr             => $net->cidr(),
                    id               => $max_id + 1,
                    created_at       => $date->epoch,
                    human_created_at => $date->to_string,
                    next_hop         => $next_hop,
                    communities      => $com_collection
                );

                push @{$entries}, $entry;
                $exaconf->write;
                $success = 1;
            }
        } else {
            $msg = $c->l('"[_1]" is not a valid IP address or network.', $cidr);
        }
    }

    $c->res->code(($success) ? 200 : 400);
    $c->render(
        json => {
            success => ($success) ? true : false,
            msg     => (defined($entry)) ? $entry->to_hash : $msg
        }
    );
}

# Modify an entry
sub put {
    my $c           = shift;
    my $id          = $c->param('id');
    my $cidr        = $c->param('cidr');
    my $next_hop    = $c->param('next_hop');
    my $communities = $c->every_param('communities[]');
    my $net         = new NetAddr::IP($cidr);

    my ($success, $msg, $entry, $com_collection) = (0, undef, undef, Mojo::Collection->new());

    # Check if the client is sending a good community
    my $communities_check = 1;
    for my $com (@{$communities}) {
        if (!defined($c->config('communities')->{$com})) {
            $msg               = $c->l('"[_1]" is not a valid community (not declared in Erco configuration).', $com);
            $communities_check = 0;
            last;
        } else {
            push @{$com_collection}, $com;
        }
    }

    if ($communities_check) {
        # Check if the client is sending a good next hop
        if (!defined($c->config('next_hops')->{$next_hop})) {
            $msg     = $c->l('"[_1]" is not a valid next hop (not declared in Erco configuration).', $next_hop);
        } elsif ($net) { # If this is OK, the client has sent a real IP or network address
            my $exaconf = $c->exaconf;
            my $entries = $exaconf->entries;

            if ($entries->modify_entry({id => $id, cidr => $net->cidr, next_hop => $next_hop, communities => $com_collection})) {
                $msg = $entries->find_entry_by_id($id)->to_hash();
                $success = 1;
                $exaconf->write;
            } else {
                $msg     = $c->l('Unable to find or modify the network with id [_1]. Please contact the administrator.', $id);
            }
        } else {
            $msg     = $c->l('"[_1]" is not a valid IP address or network.', $cidr);
        }
    }

    $c->res->code(($success) ? 200 : 400);
    $c->render(
        json => {
            success => ($success) ? true : false,
            msg     => $msg
        }
    );
}

# Delete an entry
sub delete {
    my $c = shift;
    my $id = $c->param('id');

    my ($success, $msg) = (0, undef);

    if ($c->exaconf->entries->delete($id)) {
        $msg = $c->l('Network successfully deleted.');
        $success = 1;
        $c->exaconf->write;
    } else {
        $msg     = $c->l('Unable to found the network with id = [_1]', $id);
    }

    $c->res->code(($success) ? 200 : 400);
    $c->render(
        json => {
            success => ($success) ? true : false,
            msg     => $msg
        }
    );
}

1;

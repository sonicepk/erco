# vim:set sw=4 ts=4 sts=4 ft=perl expandtab:
package Erco::Controller::API::Communities;
use Mojo::Base 'Mojolicious::Controller';

# Send the list of configured communities, JSON format
sub get {
    my $c = shift;

    $c->render(
        json => $c->config('communities')
    );
}

1;

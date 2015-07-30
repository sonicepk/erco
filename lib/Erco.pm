# vim:set sw=4 ts=4 sts=4 ft=perl expandtab:
package Erco;
use Mojo::Base 'Mojolicious';
use Erco::ExaConf;
use Unix::PID;

sub startup {
    my $self = shift;

    $self->plugin('Config' => {
        default => {
            secret   => ['fdjsofjoihrei'],
            commands => ['reload']
        }
    });

    my $commands = $self->config('commands');
    push @{$commands}, 'reload' unless (scalar(grep(/^reload$/, @{$commands})));
    $self->config->{commands} = $commands;


    # Check config needs
    my @needs;
    for my $key ('secrets', 'exabgp_conf_file', 'exabgp_pid_file', 'next_hops', 'communities') {
        push @needs, $key unless (defined($self->config($key)));
    }
    if (scalar(@needs)) {
        $self->app->log->error('The following configuration items are mandatory and not setted: '.join(', ', @needs));
        die "\n".'The following configuration items are mandatory and not setted: '.join(', ', @needs);
    }

    unless (-r $self->config('exabgp_conf_file')) {
        $self->app->log->error('The exabgp configuration file ('.$self->config('exabgp_conf_file').') is missing or not readable!');
        die "\n".'The exabgp configuration file ('.$self->config('exabgp_conf_file').') is missing or not readable!';
    }

    # Set secrets
    $self->secrets($self->config('secrets'));

    # Internationalization plugin
    $self->plugin('I18N');

    # Remote address plugin
    $self->plugin('RemoteAddr');

    # Debug plugin
    $self->plugin('DebugDumperHelper');

    $self->helper(
        exaconf => sub {
            my $c       = shift;
            state $conf = Erco::ExaConf->new(file => $c->config('exabgp_conf_file'), app => $c->app);
            return $conf;
        }
    );

    $self->helper(
        pid => sub {
            my $c = shift;
            state $pid = Unix::PID->new();
            return $pid;
        }
    );

    $self->helper(
        is_exa_running => sub {
            my $c = shift;
            return $c->pid->is_pidfile_running($c->config('exabgp_pid_file'));
        }
    );

    # Default layout
    $self->defaults(layout => 'default');

    # Router
    my $r = $self->routes;

    # Normal route to controller
    $r->get('/' => sub {
        my $c = shift;
        $c->render(
            layout   => 'default',
            template => 'index'
        );
    })->name('index');

    $r->get('/42' => sub {
        shift->render(
            layout   => 'default',
            template => 'e'
        );
    })->name('easter');

    $r->get('/js/app.js' => sub {
        shift->render(
            layout   => undef,
            template => 'js/app',
            format   => 'js'
        );
    })->name('appjs');

    ## API
    my $api = $r->under('/api');

    $api->get('/' => sub {
        shift->redirect_to('/api/index.html');
    })->name('api');

    # API: subnets
    $api->get('/subnet')
        ->to('API::Subnet#get')
        ->name('get_subnet');

    $api->post('/subnet')
        ->to('API::Subnet#post')
        ->name('add_subnet');

    $api->put('/subnet')
        ->to('API::Subnet#put')
        ->name('mod_subnet');

    $api->delete('/subnet')
        ->to('API::Subnet#delete')
        ->name('del_subnet');

    # API: misc
    $api->get('/communities')
        ->to('API::Communities#get')
        ->name('get_communities');

    $api->get('/next_hops')
        ->to('API::NextHops#get')
        ->name('get_next_hops');

    # API: exabgp
    my $exa = $r->under('/api/exabgp');

    $exa->get('/commands')
        ->to('API::Exabgp#commands')
        ->name('exabgp_commands');

    $exa->get('/command')
        ->to('API::Exabgp#command')
        ->name('exabgp_command');

    $exa->websocket('/status')
        ->to('API::Exabgp#status')
        ->name('exabgp_status');

    $exa->get('/status')
        ->to('API::Exabgp#status')
        ->name('exabgp_status');
}

1;

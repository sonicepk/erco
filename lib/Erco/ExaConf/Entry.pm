package Erco::ExaConf::Entry;
use Mojo::Base -base;
use Mojo::Date;
use Mojo::Collection;

has 'cidr';
has 'next_hop';
has 'communities' => sub { Mojo::Collection->new(); };
has 'id';
has 'created_at';
has 'human_created_at';
has 'modified_at';
has 'human_modified_at';

# Return a non-object entry, with non-object communities
sub to_hash {
    my $c = shift;

    return {
        id                => $c->id,
        cidr              => $c->cidr,
        next_hop          => $c->next_hop,
        communities       => $c->communities->to_array,
        created_at        => $c->created_at,
        human_created_at  => $c->human_created_at,
        modified_at       => $c->modified_at,
        human_modified_at => $c->human_modified_at,
    };
}

# Update the modified_at timestamp
sub modified {
    my $c    = shift;
    my $date = Mojo::Date->new(time);
    $c->modified_at($date->epoch);
    $c->human_modified_at($date->to_string);

    return $c
}

1;

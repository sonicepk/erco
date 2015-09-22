# vim:set sw=4 ts=4 sts=4 ft=perl expandtab:
package Erco::ExaConf::Entries;
use Mojo::Base 'Mojo::Collection';

# Delete an entry
sub delete {
    my $c  = shift;
    my $id = shift;

    my $deleted = 0;
    $c->each(
        sub {
            my ($e, $num) = @_;
            if (defined($e) && $e->id == $id) {
                delete $c->[$num - 1];
                $deleted = 1;
            }
        }
    );

    return $deleted;
}

# Modify an entry
sub modify {
    my $c    = shift;
    my $id   = shift;
    my $cidr = shift;

    my $modified = 0;
    $c = Erco::ExaConf::Entries->new($c->each(
        sub {
            my ($e, $num) = @_;
            if (defined($e) && $e->id == $id) {
                $e->cidr($cidr);
                $e->modified();
                $modified = 1;
            }
        }
    ));

    return $modified;
}

# Overriding to_array method to "flatten" entries
sub to_array {
    my $c = shift;

    my @data;
    $c->each(
        sub {
            my ($e, $num) = @_;
            if (defined($e)) {
                push @data, $e->to_hash();
            }
        }
    );

    return \@data;
}

# Return the maximum id of the entries (to be able to choose a new one)
sub max_id {
    my $c = shift;

    my $max_id  = 0;
    $c->each(
        sub {
            my ($e, $num) = @_;
            $max_id = $e->id if (defined($e) && $e->id > $max_id);
        }
    );

    return $max_id;
}

# Modify an entry
sub modify_entry {
    my $c    = shift;
    my $args = shift;
    my $id   = $args->{id};

    my $entry = $c->find_entry_by_id($id);

    if (defined($entry)) {
        for my $key (keys %{$args}) {
            $entry->$key($args->{$key});
        }
        $entry->modified();

        return 1;
    } else {
        return 0;
    }
}

# Find entry by its cidr
sub find_entry_by_cidr {
    my $c    = shift;
    my $cidr = shift;

    return $c->grep(
        sub {
            my $e = $_;
            if (defined($e)) {
                return ($e->cidr eq $cidr) ? 1 : 0;
            }
        }
    )->first;
}

# Find entry by its id
sub find_entry_by_id {
    my $c  = shift;
    my $id = shift;

    return $c->grep(
        sub {
            my $e  = $_;
            if (defined($e)) {
                return ($e->id eq $id) ? 1 : 0;
            }
        }
    )->first;
}

# Find multiple entries by their ids
sub find_entries_by_ids {
    my $c   = shift;
    my $ids = shift;
    return $c->grep(
        sub {
            my $e  = $_;
            if (defined($e)) {
                for my $id (@{$ids}) {
                    return 1 if ($e->id == $id);
                }
                return 0;
            }
        }
    );
}

1;

# vim:set sw=4 ts=4 sts=4 ft=perl expandtab:
use Mojo::Base -strict;
use Mojo::JSON qw(true false);

use Test::More;
use Test::Mojo;

my $t = Test::Mojo->new('Erco');
$t->get_ok('/')
  ->status_is(200)
  ->content_like(qr/Erco/i);

# Next hops API
$t->get_ok('/api/next_hops')
  ->status_is(200)
  ->json_is({'203.0.113.42' => 'bender.example.org', '198.51.100.42' => 'zoidberg.example.org'});

# Communities API
$t->get_ok('/api/communities')
  ->status_is(200)
  ->json_is({'1337:1984' => 'Planet express community', '42:1984' => 'Nude Beach Planet'});

# Exabgp API
$t->websocket_ok('/api/exabgp/status')
  ->message_ok
  ->json_message_is({file_missing => false, running => true})
  ->finish_ok;

$t->get_ok('/api/exabgp/status')
  ->status_is(200)
  ->json_is({file_missing => false, running => true});

$t->get_ok('/api/exabgp/commands')
  ->status_is(200)
  ->json_is(['version','show neighbors','show routes','reload']);

$t->get_ok('/api/exabgp/command' => form => {action => 'version'})
  ->status_is(200)
  ->json_is({success => true, msg => 'exabgp 3.4.11'});

$t->get_ok('/api/exabgp/command' => form => {action => 'reload'})
  ->status_is(200)
  ->json_is({success => true, msg => 'Exabgp has been successfully reloaded.'});

$t->get_ok('/api/exabgp/command' => {'Accept-Language' => 'fr,fr-FR;q=0.8'} => form => {action => 'reload'})
  ->status_is(200)
  ->json_is({success => true, msg => 'Exabgp a été relancé avec succès.'});

$t->get_ok('/api/exabgp/command' => form => {action => 'show neighbors'})
  ->status_is(200)
  ->json_has('success', 'msg')
  ->json_like('/success' => qr/1/, '/msg' => qr/neighbor/);

$t->get_ok('/api/exabgp/command' => form => {action => 'show routes'})
  ->status_is(200)
  ->json_is({success => true, msg => 'neighbor 193.50.27.45 127.0.0.0/24 next-hop 198.51.100.42'});

$t->get_ok('/api/exabgp/command' => form => {action => 'restart'})
  ->status_is(200)
  ->json_is({success => false, msg => 'You tried to launch an unauthorized command. Contact an administrator.'});

$t->get_ok('/api/exabgp/command' => form => {action => 'foobarbaz'})
  ->status_is(200)
  ->json_is({success => false, msg => 'You tried to launch an unauthorized command. Contact an administrator.'});

# Subnet API
$t->get_ok('/api/subnet')
  ->status_is(200)
  ->json_like('/0/created_at' => qr/\d+/)
  ->json_is('/0/next_hop'     => '198.51.100.42', '/0/id'            => 1,
            '/0/cidr'         => '127.0.0.0/24',  '/0/communities/0' => '1337:1984');

$t->post_ok('/api/subnet' => form => {cidr => '198.51.100.43/32', next_hop => '203.0.113.42', 'communities[]' => ['1337:1984', '42:1984']})
  ->status_is(200)
  ->json_has('success', 'msg')
  ->json_is('/success'          => true,           '/msg/id'   => 2,
            '/msg/next_hop'     => '203.0.113.42', '/msg/cidr' => '198.51.100.43/32',
            '/msg/communities'  => ['1337:1984', '42:1984'])
  ->json_like('/msg/created_at' => qr/\d+/);

$t->get_ok('/api/subnet')
  ->status_is(200)
  ->json_like('/0/created_at' => qr/\d+/)
  ->json_is('/0/next_hop'     => '198.51.100.42', '/0/id'             => 1,
            '/0/cidr'         => '127.0.0.0/24',  '/0/communities/0'  => '1337:1984')
  ->json_like('/1/created_at' => qr/\d+/)
  ->json_is('/1/next_hop'     => '203.0.113.42',     '/1/id'          => 2,
            '/1/cidr'         => '198.51.100.43/32', '/1/communities' => ['1337:1984', '42:1984']);

$t->delete_ok('/api/subnet' => form => { id => 2 })
  ->status_is(200)
  ->json_has('success', 'msg')
  ->json_is({success => true, msg => 'Network successfully deleted.'});

$t->get_ok('/api/subnet')
  ->status_is(200)
  ->json_like('/0/created_at' => qr/\d+/)
  ->json_is('/0/next_hop'     => '198.51.100.42', '/0/id'            => 1,
            '/0/cidr'         => '127.0.0.0/24',  '/0/communities/0' => '1337:1984');

$t->put_ok('/api/subnet' => form => { id => 1, cidr => '127.0.0.0/24', 'next_hop' => '198.51.100.42', 'communities[]' => ['1337:1984', '42:1984']})
  ->status_is(200)
  ->json_has('success', 'msg')
  ->json_like('/msg/created_at' => qr/\d+/)
  ->json_is('/success'          => true,            '/msg/id'   => 1,
            '/msg/next_hop'     => '198.51.100.42', '/msg/cidr' => '127.0.0.0/24',
            '/msg/communities'  => ['1337:1984', '42:1984']);

$t->get_ok('/api/subnet')
  ->status_is(200)
  ->json_like('/0/created_at' => qr/\d+/)
  ->json_is('/0/next_hop'     => '198.51.100.42', '/0/id'          => 1,
            '/0/cidr'         => '127.0.0.0/24',  '/0/communities' => ['1337:1984', '42:1984']);

done_testing();

# This is a regression test to cover the auth_type parsing logic.

use strict;
use warnings;
use lib 'lib';

use Test::More;

my $SAVED_REQUEST;

# A simple API class with a single method: GET https://myapi/do_something
package MyAPI {
  use Mouse;
  with 'Web::API';

  has '+user_agent' => ( default => sub { 'test' } );

  sub commands { { do_something => { method => 'GET' } } }

  # Intercept and save the request (and don't send it)
  around 'request' => sub {
    my ($orig, $self, $request) = @_;
    $SAVED_REQUEST = $request;
    return;
  };

  # Clear the saved request ahead of each API call
  before 'talk' => sub { $SAVED_REQUEST = undef };

  sub BUILD { shift->live_url('https://myapi') }
}

subtest 'Auth type basic' => sub {
  my $api = MyAPI->new(
    auth_type => 'basic',
    user      => 'Bonzo',
    api_key   => 'sausages',
  );
  $api->do_something();
  is $SAVED_REQUEST->uri, 'https://Bonzo:sausages@myapi/do_something',
    'Auth creds in URL';
};

subtest 'Auth type header' => sub {
  my $api = MyAPI->new(
    auth_type => 'header',
    api_key   => 'sausages',
  );
  $api->do_something();
  like $SAVED_REQUEST->headers->header('Authorization'), qr/token=sausages/,
    'Auth header with token';
};

subtest 'Auth type hash_key' => sub {
  my $api = MyAPI->new(
    auth_type => 'hash_key',
    api_key   => 'sausages'
  );
  $api->do_something();
  is $SAVED_REQUEST->uri, 'https://myapi/do_something?key=sausages',
    'Auth key in query string';
};

subtest 'Auth type get_params' => sub {
  my $api = MyAPI->new(
    auth_type => 'get_params',
    user      => 'Bonzo',
    api_key   => 'sausages',
    mapping   => {api_key => 'key'},
  );
  $api->do_something();
  is $SAVED_REQUEST->uri, 'https://myapi/do_something?user=Bonzo&key=sausages',
    'Auth creds in query string';
};

subtest 'Auth type oauth_params' => sub {
  my $api = MyAPI->new(
    auth_type       => 'oauth_params',
    api_key         => 'sausages',
    access_token    => 'my_token',
    access_secret   => 'my_token_secret',
    consumer_secret => 'my_consumer_secret',
  );
  $api->do_something();
  my @oauth_keys = qw(
    oauth_consumer_key oauth_nonce oauth_signature oauth_signature_method
    oauth_timestamp oauth_token oauth_version
  );
  like $SAVED_REQUEST->uri, qr/$_/, "Oauth key '$_' in querystring"
    for @oauth_keys;
};
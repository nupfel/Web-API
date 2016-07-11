use lib 't/lib';
use Test::More;
use Test::Exception;
use Web::API::Test;

my $api = Web::API::Test->new();
isa_ok($api, 'Web::API::Test');

dies_ok
    { $api->build_uri('mandatory', undef, $api->commands->{mandatory}->{path} ) }
    'mandatory attribute';

isa_ok(
    $api->build_uri('mandatory', { id => 'bar' }, $api->commands->{mandatory}->{path} ),
    'URI'
);

is(
    $api->build_uri('mandatory', { id => 'bar' }, $api->commands->{mandatory}->{path} ),
    'http://localhost/mandatory/bar',
    'mandatory attribute in URI'
);

lives_ok
    { $api->build_uri('optional', undef, $api->commands->{optional}->{path} ) }
    'optional attribute';

isa_ok(
    $api->build_uri('optional', undef, $api->commands->{optional}->{path} ),
    'URI'
);

is(
    $api->build_uri('optional', undef, $api->commands->{optional}->{path} ),
    'http://localhost/optional',
    'optional attribute not in URI when not used'
);

is(
    $api->build_uri('optional', { id => 'foo' }, $api->commands->{optional}->{path} ),
    'http://localhost/optional/foo',
    'optional attribute in URI when used'
);

is(
    $api->build_uri('multi_level', { id => 'foo' }, $api->commands->{multi_level}->{path} ),
    'http://localhost/multi-level/foo',
    'multi-level without optional attribute'
);

is(
    $api->build_uri('multi_level', { id => 'foo', class => 'bar' }, $api->commands->{multi_level}->{path} ),
    'http://localhost/multi-level/foo/bar',
    'multi-level with optional attribute'
);

done_testing;

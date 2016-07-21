package Web::API::Test;

use Test::More;
use Mouse;
use lib 'lib';

with 'Web::API';

has 'commands' => (
    is      => 'rw',
    default => sub {
        {
            mandatory => {
                path => 'mandatory/:id',
            },
            optional => {
                path => 'optional/:id?',
            },
            multi_level => {
                path => 'multi-level/:id/:class?',
            },
        };
    },
);

sub commands {
    my ($self) = @_;
    return $self->commands;
}

sub BUILD {
    my ($self) = @_;

    $self->base_url('http://localhost');

    return $self;
}

1;

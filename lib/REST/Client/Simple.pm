package REST::Client::Simple;

use 5.010;
use Any::Moose 'Role';
use LWP::UserAgent;
use HTTP::Cookies;
use Data::Dumper;
use XML::Simple;
use URI::Escape::XS qw/uri_escape uri_unescape/;
use JSON;
use URI;
use Carp;

our $AUTOLOAD;

=head1 NAME

REST::Client::Simple - A Simple base module to implement almost every RESTful API with just a few lines of configuration

=head1 VERSION

Version 0.3

=cut

our $VERSION = "0.3";

=head1 SYNOPSIS

Implement the RESTful API of your choice in 10 minutes, roughly.

    package Net::CloudProvider;

    use Any::Moose;
    use Data::Dumper;
    with 'REST::Client::Simple';

    our $VERSION = "0.1";

    has 'commands' => (
        is      => 'rw',
        default => sub {
            {
                list_nodes => { method => 'GET' },
                node_info  => { method => 'GET', require_id => 1 },
                create_node => {
                    method             => 'POST',
                    default_attributes => {
                        allowed_hot_migrate            => 1,
                        required_virtual_machine_build => 1,
                        cpu_shares                     => 5,
                        required_ip_address_assignment => 1,
                        primary_network_id             => 1,
                        required_automatic_backup      => 0,
                        swap_disk_size                 => 1,
                    },
                    mandatory_attributes => [
                        'label',
                        'hostname',
                        'template_id',
                        'cpus',
                        'memory',
                        'primary_disk_size',
                        'required_virtual_machine_build',
                        'cpu_shares',
                        'primary_network_id',
                        'required_ip_address_assignment',
                        'required_automatic_backup',
                        'swap_disk_size',
                    ]
                },
                update_node => { method => 'PUT',    require_id => 1 },
                delete_node => { method => 'DELETE', require_id => 1 },
                start_node  => {
                    method       => 'POST',
                    require_id   => 1,
                    post_id_path => 'startup',
                },
                stop_node => {
                    method       => 'POST',
                    require_id   => 1,
                    post_id_path => 'shutdown',
                },
                suspend_node => {
                    method       => 'POST',
                    require_id   => 1,
                    post_id_path => 'suspend',
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

        $self->user_agent("Net::CloudProvider $VERSION");
        $self->base_url('https://ams01.cloudprovider.net/virtual_machines');
        $self->content_type('application/json');
        $self->extension('json');
        $self->wrapper_key('virtual_machine');
        $self->mapping({
                os        => 'template_id',
                debian    => 1,
                id        => 'label',
                disk_size => 'primary_disk_size',
        });

        return $self;
    }

    1;
        
later use as:

    use Net::CloudProvider;
    
    my $nc = Net::CloudProvider(user => 'foobar', api_key => 'secret');
    my $response = $nc->create_node({
        id                             => 'funnybox',
        hostname                       => 'node.funnybox.com',
        os                             => 'debian',
        cpus                           => 2,
        memory                         => 256,
        disk_size                      => 5,
        allowed_hot_migrate            => 1,
        required_virtual_machine_build => 1,
        cpu_shares                     => 5,
        required_ip_address_assignment => 1,
    });
    print Dumper($response);


=head1 ATTRIBUTES

=head2 commands

most important configuration part of the module which has to be provided by the
module you are writing.

the following keys are valid/possible:

    method
    require_id
    path
    pre_id_path
    post_id_path
    wrapper_key
    default_attributes
    mandatory_attributes
    extension
    content_type
    incoming_content_type
    outgoing_content_type

the request path for non require_id commands is being build as:

    $base_url/$path.$extension

accordingly requests with require_id:

    $base_url/$pre_id_path/$id/$post_id_path.$extension

whereas $id can be any arbitrary object like a domain, that the API in question
does operations on.

=cut

requires 'commands';

=head2 base_url (required)

get/set base URL to API, can include paths

=cut

has 'base_url' => (
    is  => 'rw',
    isa => 'Str',
);

=head2 user (required)

get/set username/account name

=cut

has 'user' => (
    is       => 'rw',
    isa      => 'Str',
    required => 1,
);

=head2 api_key (required)

get/set api_key

=cut

has 'api_key' => (
    is       => 'rw',
    isa      => 'Str',
    required => 1,
);

=head2 mapping (optional)

supply mapping table, hashref of format { key => value }

default: undef

=cut

has 'mapping' => (
    is      => 'rw',
    default => sub { {} },
);

=head2 wrapper_key (optional)

=cut

has 'wrapper_key' => (
    is      => 'rw',
    isa     => 'Str',
    clearer => 'clear_wrapper_key',
);

=head2 header (optional)

get/set custom headers sent with each request

=cut

has 'header' => (
    is      => 'rw',
    lazy    => 1,
    default => sub { {} },
);

=head2

get/set authentication type. currently supported are only 'basic' or none

default: basic

=cut

has 'auth_type' => (
    is  => 'rw',
    isa => 'Str',
);

=head2 extension (optional)

get/set file extension, e.g. '.json'

=cut

has 'extension' => (
    is  => 'rw',
    isa => 'Str',
);

=head2 user_agent (optional)

get/set User Agent String

default: "REST::Client::Simple $VERSION"

=cut

has 'user_agent' => (
    is      => 'rw',
    isa     => 'Str',
    default => sub { "REST::Client::Simple $VERSION" },
);

=head2 timeout (optional)

get/set LWP::UserAgent timeout

=cut

has 'timeout' => (
    is       => 'rw',
    isa      => 'Int',
    default  => sub { 30 },
    required => 1,
);

=head2 agent (optional)

get/set REST::Client object

=cut

has 'agent' => (
    is       => 'rw',
    isa      => 'LWP::UserAgent',
    lazy     => 1,
    required => 1,
    builder  => '_build_agent',
);

=head2 content_type (optional)

default: 'text/plain'

=cut

has 'content_type' => (
    is      => 'rw',
    isa     => 'Str',
    default => sub { 'text/plain' },
);

=head2 incoming_content_type (optional)

default: undef

=cut

has 'incoming_content_type' => (
    is  => 'rw',
    isa => 'Str',
);

=head2 outgoing_content_type (optional)

default: undef

=cut

has 'outgoing_content_type' => (
    is  => 'rw',
    isa => 'Str',
);

=head2 debug (optional)

default: 0

=cut

has 'debug' => (
    is      => 'rw',
    isa     => 'Bool',
    default => sub { 0 },
    lazy    => 1,
);

has 'cookies' => (
    is      => 'rw',
    isa     => 'HTTP::Cookies',
    default => sub { HTTP::Cookies->new },
);

sub _build_agent {
    my ($self) = @_;

    return LWP::UserAgent->new(
        agent      => $self->user_agent,
        cookie_jar => $self->cookies,
        timeout    => $self->timeout,
        ssl_opts   => { verify_hostname => 0 },
    );
}

=head1 INTERNAL SUBROUTINES/METHODS

=head2 decode

=cut

sub decode {
    my ($self, $content, $content_type) = @_;

    my $data;
    eval {
        given ($content_type)
        {
            when (/text/) { $data = $content; }
            when (/urlencoded/) {
                foreach (split(/&/, $content)) {
                    my ($key, $value) = split(/=/, $_);
                    $data->{ uri_unescape($key) } = uri_unescape($value);
                }
            }
            when (/json/) { $data = JSON->new->utf8->decode($content) }
            when (/xml/) { $data = XMLin($content, forcecontent => 1) }
        }
    };
    return { error => "couldn't decode payload using $content_type: $@\n"
            . Dumper($content) }
        if ($@ || ref \$content ne 'SCALAR');

    return $data;
}

=head2 encode

=cut

sub encode {
    my ($self, $options, $content_type) = @_;

    my $payload;
    eval {
        given ($content_type)
        {
            when (/text/) { $payload = $options; }
            when (/urlencoded/) {
                $payload .=
                    uri_escape($_) . '=' . uri_escape($options->{$_}) . '&'
                    foreach (keys %$options);
                chop($payload);
            }
            when (/json/) {
                $payload = JSON->new->utf8->allow_nonref->encode($options);
            }
            when (/xml/) { $payload = XMLout($options); }
        }
    };
    return { error => "couldn't encode payload using $content_type: $@\n"
            . Dumper($options) }
        if ($@ || ref \$payload ne 'SCALAR');

    return $payload;
}

=head2 talk

=cut

sub talk {
    my ($self, $command, $uri, $options, $content_type) = @_;

    my $method = uc $command->{method};

    $uri->userinfo($self->user . ':' . $self->api_key)
        if ($self->auth_type and (lc $self->auth_type eq 'basic'));

    my $payload;
    if (keys %$options) {
        $payload = $self->encode($options, $content_type->{out});

        # got an error while encoding, return it
        return $payload if (ref $payload eq 'HASH' && exists $payload->{error});

        print "send payload: $payload\n" if $self->debug;

        $uri .= '?' . $payload
            if (($method eq 'GET') and ($content_type->{out} =~ m/urlencoded/));
    }

    print "uri: $method $uri\n" if $self->debug;
    print "extra header:\n" . Dumper($self->header)
        if (%{ $self->header } && $self->debug);

    # build headers/request
    my $headers =
        HTTP::Headers->new(%{ $self->header }, "Accept" => $content_type->{in});
    my $request = HTTP::Request->new($method, $uri, $headers);
    unless ($method =~ m/^(GET|HEAD|DELETE)$/) {
        $request->header("Content-type" => $content_type->{out});
        $request->content($payload);
    }

    # do the actual work
    $self->agent->cookie_jar($self->cookies);
    my $response = $self->agent->request($request);

    unless ($response->is_success || $response->is_redirect) {
        print "error: " . $response->status_line . $/ if $self->debug;
        return { error => "request failed: " . $response->status_line };
    }

    print "recv payload: " . $response->decoded_content . $/
        if $self->debug;

    # collect response headers
    my $response_headers;
    $response_headers->{$_} = $response->header($_)
        foreach ($response->header_field_names);

    return {
        header => $response_headers,
        code   => $response->code,
        content =>
            $self->decode($response->decoded_content, $content_type->{in}),
    };
}

=head2 map_options

=cut

sub map_options {
    my ($self, $options, $command) = @_;

    # check existence of mandatory attributes
    if ($command->{mandatory_attributes}) {
        print "mandatory keys:\n"
            . Dumper(\@{ $command->{mandatory_attributes} })
            if $self->debug;
        my @missing_attrs;
        foreach my $attr (@{ $command->{mandatory_attributes} }) {
            push(@missing_attrs, $attr) unless (exists $options->{$attr});
        }
        return { error => 'mandatory attributes for this command missing: '
                . join(', ', @missing_attrs) }
            if @missing_attrs;
    }

    unless ($command->{no_mapping}) {
        print "mapping hash:\n" . Dumper($self->mapping) if $self->debug;

        my %opts;

        # first include assumed to be already mapped default attributes
        %opts = %{ $command->{default_attributes} }
            if (exists $command->{default_attributes});

        # do the key and value mapping of options hash and overwrite defaults
        foreach my $key (keys %$options) {
            my $newkey = $self->mapping->{$key} if ($self->mapping->{$key});
            my $newvalue = $self->mapping->{ $options->{$key} }
                if ($self->mapping->{ $options->{$key} });

            $opts{ $newkey || $key } = $newvalue || $options->{$key};
        }
        $options = \%opts;
    }

    # wrap all options in wrapper key if required
    my $wrapper_key = $command->{wrapper_key} || $self->wrapper_key;
    $options = { $wrapper_key => $options } if (defined $wrapper_key);
    print "options:\n" . Dumper($options) if $self->debug;

    return $options;
}

=head2 AUTOLOAD magic

=cut

sub AUTOLOAD {
    my ($self, $options) = @_;

    my ($name) = $AUTOLOAD =~ /([^:]+)$/;

    return { error => "unknown command: $name" }
        unless (exists $self->commands->{$name});

    # construct URI path
    my $uri  = URI->new($self->base_url);
    my $path = $uri->path;
    $path .= '/' . $self->commands->{$name}->{path}
        if (exists $self->commands->{$name}->{path});
    if ($self->commands->{$name}->{require_id}) {
        return { error => "required {id} attribute missing" }
            unless (exists $options->{id});
        my $id = delete $options->{id};
        $path .= '/' . $self->commands->{$name}->{pre_id_path}
            if (exists $self->commands->{$name}->{pre_id_path});
        $path .= '/' . $id;
        $path .= '/' . $self->commands->{$name}->{post_id_path}
            if (exists $self->commands->{$name}->{post_id_path});
    }
    $path .= '.' . $self->extension if (defined $self->extension);
    $uri->path($path);

    # configure in/out content types
    my $content_type;
    $content_type->{in} =
           $self->commands->{$name}->{incoming_content_type}
        || $self->commands->{$name}->{content_type}
        || $self->incoming_content_type
        || $self->content_type;
    $content_type->{out} =
           $self->commands->{$name}->{outgoing_content_type}
        || $self->commands->{$name}->{content_type}
        || $self->outgoing_content_type
        || $self->content_type;

    # manage options
    $options = $self->map_options($options, $self->commands->{$name})
        if ((
                (keys %$options)
            and ($content_type->{out} =~ m/(xml|json|urlencoded)/))
        or (exists $self->commands->{$name}->{default_attributes}));
    return $options if (exists $options->{error});

    # do the call
    return $self->talk($self->commands->{$name}, $uri, $options, $content_type);
}

=head1 AUTHOR

Tobias Kirschstein, C<< <mail at lev.geek.nz> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-rest-client-simple at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=REST-Client-Simple>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 TODO

=over 1

=item * add OAuth athentication possibility

=back

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc REST::Client::Simple


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=REST-Client-Simple>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/REST-Client-Simple>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/REST-Client-Simple>

=item * Search CPAN

L<http://search.cpan.org/dist/REST-Client-Simple/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2012 Tobias Kirschstein.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1;

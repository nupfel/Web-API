package Web::API;

use 5.010001;
use Mouse::Role;
use experimental 'smartmatch';

# ABSTRACT: Web::API - A Simple base module to implement almost every RESTful API with just a few lines of configuration

# VERSION

use LWP::UserAgent;
use HTTP::Cookies;
use Data::Dump 'dump';
use XML::Simple;
use URI::Escape::XS qw/uri_escape uri_unescape/;
use JSON;
use URI;
use URI::QueryParam;
use Carp;
use Net::OAuth;
use Data::Random qw(rand_chars);

$Net::OAuth::PROTOCOL_VERSION = Net::OAuth::PROTOCOL_VERSION_1_0A;

our $AUTOLOAD;

our %CONTENT_TYPE = (
    json => 'application/json',
    js   => 'application/json',
    xml  => 'text/xml',
);

=head1 SYNOPSIS

Implement the RESTful API of your choice in 10 minutes, roughly.

    package Net::CloudProvider;

    use Any::Moose;
    with 'Web::API';

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
                    mandatory => [
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

        $self->user_agent(__PACKAGE__ . ' ' . $VERSION);
        $self->base_url('https://ams01.cloudprovider.net/virtual_machines');
        $self->content_type('application/json');
        $self->extension('json');
        $self->wrapper('virtual_machine');
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
    wrapper
    default_attributes
    mandatory
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

=head2 api_key (required)

get/set api_key

=cut

has 'api_key' => (
    is  => 'rw',
    isa => 'Str',
);

=head2 user (optional)

get/set username/account name

=cut

has 'user' => (
    is  => 'rw',
    isa => 'Str',
);

=head2 api_key_field (optional)

get/set name of the hash key in the POST data structure that has to hold the api_key

=cut

has 'api_key_field' => (
    is      => 'rw',
    isa     => 'Str',
    default => sub { 'key' },
);

=head2 mapping (optional)

supply mapping table, hashref of format { key => value }

default: undef

=cut

has 'mapping' => (
    is      => 'rw',
    default => sub { {} },
);

=head2 wrapper (optional)

=cut

has 'wrapper' => (
    is      => 'rw',
    clearer => 'clear_wrapper',
);

=head2 header (optional)

get/set custom headers sent with each request

=cut

has 'header' => (
    is      => 'rw',
    lazy    => 1,
    default => sub { {} },
);

=head2 auth_type

get/set authentication type. currently supported are only 'basic', 'hash_key', 'get_params', 'oauth_header', 'oauth_params' or 'none'

default: none

=cut

has 'auth_type' => (
    is      => 'rw',
    isa     => 'Str',
    default => sub { 'none' },
);

=head2 default_method (optional)

get/set default HTTP method

default: GET

=cut

has 'default_method' => (
    is      => 'rw',
    isa     => 'Str',
    default => sub { 'GET' },
);

=head2 extension (optional)

get/set file extension, e.g. '.json'

=cut

has 'extension' => (
    is      => 'rw',
    isa     => 'Str',
    default => sub { '' },
);

=head2 user_agent (optional)

get/set User Agent String

default: "Web::API $VERSION"

=cut

has 'user_agent' => (
    is      => 'rw',
    isa     => 'Str',
    default => sub { __PACKAGE__ . ' ' . $Web::API::VERSION },
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

=head2 strict_ssl (optional)

enable/disable strict SSL certificate hostname checking

default: false

=cut

has 'strict_ssl' => (
    is       => 'rw',
    isa      => 'Bool',
    default  => sub { 0 },
    lazy     => 1,
    required => 1,
);

=head2 agent (optional)

get/set LWP::UserAgent object

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

=head2 cookies (optional)

default: HTTP::Cookies->new

=cut

has 'cookies' => (
    is      => 'rw',
    isa     => 'HTTP::Cookies',
    default => sub { HTTP::Cookies->new },
);

=head2 consumer_secret (required for all oauth_* auth_types)

default: undef

=cut

has 'consumer_secret' => (
    is  => 'rw',
    isa => 'Str',
);

=head2 access_token (required for all oauth_* auth_types)

default: undef

=cut

has 'access_token' => (
    is  => 'rw',
    isa => 'Str',
);

=head2 access_secret (required for all oauth_* auth_types)

default: undef

=cut

has 'access_secret' => (
    is  => 'rw',
    isa => 'Str',
);

=head2 signature_method (required for all oauth_* auth_types)

default: undef

=cut

has 'signature_method' => (
    is      => 'rw',
    isa     => 'Str',
    default => sub { 'HMAC-SHA1' },
    lazy    => 1,
);

=head2 encoder (custom options encoding subroutine)

Receives options and content-type as the only 2 arguments

default: undef

=cut

has 'encoder' => (
    is        => 'rw',
    isa       => 'CodeRef',
    predicate => 'has_encoder',
);

=head2 decoder (custom response content decoding subroutine)

Receives content and content-type as the only 2 arguments

default: undef

=cut

has 'decoder' => (
    is        => 'rw',
    isa       => 'CodeRef',
    predicate => 'has_decoder',
);

=head2 oauth_post_body (required for all oauth_* auth_types)

default: true

=cut

has 'oauth_post_body' => (
    is      => 'rw',
    isa     => 'Bool',
    default => sub { 1 },
    lazy    => 1,
);

has 'json' => (
    is      => 'rw',
    isa     => 'JSON',
    default => sub {
        my $js = JSON->new;
        $js->utf8;
        $js->allow_blessed;
        $js->convert_blessed;
        $js->allow_nonref;
        $js;
    },
);

has 'xml' => (
    is      => 'rw',
    isa     => 'XML::Simple',
    lazy    => 1,
    default => sub {
        XML::Simple->new(
            ContentKey => '-content',
            NoAttr     => 1,
            KeepRoot   => 1,
            KeyAttr    => {},
        );
    },
);

sub _build_agent {
    my ($self) = @_;

    return LWP::UserAgent->new(
        agent      => $self->user_agent,
        cookie_jar => $self->cookies,
        timeout    => $self->timeout,
        ssl_opts   => { verify_hostname => $self->strict_ssl },
    );
}

=head1 INTERNAL SUBROUTINES/METHODS

=head2 nonce

generates new OAuth nonce for every request

=cut

sub nonce {
    return join('', rand_chars(size => 16, set => 'alphanumeric'));
}

=head2 log

=cut

sub log {    ## no critic (ProhibitBuiltinHomonyms)
    my ($self, $msg) = @_;
    print STDERR __PACKAGE__ . ': ' . $msg . $/;
    return;
}

=head2 decode

=cut

sub decode {
    my ($self, $content, $content_type) = @_;

    my $data;
    eval {
        if ($self->has_decoder) {
            $self->log('running custom decoder') if $self->debug;
            $data = $self->decoder->($content, $content_type);
        }
        else {
            given ($content_type) {
                when (/plain/) { $data = $content; }
                when (/urlencoded/) {
                    foreach (split(/&/, $content)) {
                        my ($key, $value) = split(/=/, $_);
                        $data->{ uri_unescape($key) } = uri_unescape($value);
                    }
                }
                when (/json/) { $data = $self->json->decode($content); }
                when (/xml/) {
                    $data = $self->xml->XMLin($content, NoAttr => 0);
                }
            }
        }
    };
    return { error => "couldn't decode payload using $content_type: $@\n"
            . dump($content) }
        if ($@ || ref \$content ne 'SCALAR');

    return $data;
}

=head2 encode

=cut

sub encode {
    my ($self, $options, $content_type) = @_;

    my $payload;
    eval {
        # custom encoder should only be run if called by Web::API otherwise we
        # end up calling it twice
        if ($self->has_encoder and caller(1) eq 'Web::API') {
            $self->log('running custom encoder') if $self->debug;
            $payload = $self->encoder->($options, $content_type);
        }
        else {
            given ($content_type) {
                when (/plain/) { $payload = $options; }
                when (/urlencoded/) {
                    $payload .=
                        uri_escape($_) . '=' . uri_escape($options->{$_}) . '&'
                        foreach (keys %$options);
                    chop($payload);
                }
                when (/json/) { $payload = $self->json->encode($options); }
                when (/xml/)  { $payload = $self->xml->XMLout($options); }
            }
        }
    };
    return { error => "couldn't encode payload using $content_type: $@\n"
            . dump($options) }
        if ($@ || ref \$payload ne 'SCALAR');

    return $payload;
}

=head2 talk

=cut

sub talk {
    my ($self, $command, $uri, $options, $content_type) = @_;

    my $method = uc($command->{method} || $self->default_method);
    my $oauth_req;

    # handle different auth_types
    given (lc $self->auth_type) {
        when ('basic') { $uri->userinfo($self->user . ':' . $self->api_key); }
        when ('hash_key') {
            $options->{ $self->api_key_field } = $self->api_key;
        }
        when ('get_params') {
            $uri->query_form(
                $self->mapping->{user}    || 'user'    => $self->user,
                $self->mapping->{api_key} || 'api_key' => $self->api_key,
            );
        }
        when (/^oauth/) {
            my %opts = (
                consumer_key     => $self->api_key,
                consumer_secret  => $self->consumer_secret,
                request_url      => $uri,
                request_method   => $method,
                signature_method => $self->signature_method,
                timestamp        => time,
                nonce            => $self->nonce,
                token            => $self->access_token,
                token_secret     => $self->access_secret,
            );

            if (
                $options
                and (($self->oauth_post_body and $method eq 'POST')
                    or $method ne 'POST'))
            {
                $opts{extra_params} = $options;
            }

            $oauth_req = Net::OAuth->request("protected resource")->new(%opts);
            $oauth_req->sign;
        }
        default {
            $self->log(
                "WARNING: auth_type " . $self->auth_type . " not supported yet")
                unless (lc($self->auth_type) eq 'none');
        }
    }

    # encode payload
    my $payload;
    if (keys %$options) {
        if ($method =~ m/^(GET|HEAD|DELETE)$/) {

            # TODO: check whether $option is a flat hashref

            unless ($self->auth_type eq 'oauth_params') {
                $uri->query_param_append($_ => $options->{$_})
                    for (keys %$options);
            }
        }
        else {
            $payload = $self->encode($options, $content_type->{out});

            # got an error while encoding? return it
            return $payload
                if (ref $payload eq 'HASH' && exists $payload->{error});

            $self->log("send payload: $payload") if $self->debug;
        }
    }

    $uri = $oauth_req->to_url if ($self->auth_type eq 'oauth_params');

    # build headers
    my %header;
    if (exists $command->{headers} and ref $command->{headers} eq 'HASH') {
        %header = (%{ $self->header }, %{ $command->{headers} });
    }
    else {
        %header = %{ $self->header };
    }
    my $headers = HTTP::Headers->new(%header, "Accept" => $content_type->{in});

    if ($self->debug) {
        $self->log("uri: $method $uri");
        $self->log("extra headers: " . dump(\%header)) if (%header);
        $self->log("OAuth headers: " . $oauth_req->to_authorization_header)
            if ($self->auth_type eq 'oauth_header');
    }

    # build request
    my $request = HTTP::Request->new($method, $uri, $headers);
    unless ($method =~ m/^(GET|HEAD|DELETE)$/) {
        $request->header("Content-type" => $content_type->{out});
        $request->content($payload);
    }

    # oauth POST
    if (    $options
        and ($method eq 'POST')
        and ($self->auth_type =~ m/^oauth/)
        and $self->oauth_post_body)
    {
        $request->content($oauth_req->to_post_body);
    }

    # oauth_header
    $request->header(Authorization => $oauth_req->to_authorization_header)
        if ($self->auth_type eq 'oauth_header');

    # do the actual work
    $self->agent->cookie_jar($self->cookies);
    my $response = $self->agent->request($request);

    $self->log("recv payload: " . $response->decoded_content)
        if $self->debug;

    # collect response headers
    my $response_headers;
    $response_headers->{$_} = $response->header($_)
        foreach ($response->header_field_names);

    my $answer = {
        header  => $response_headers,
        code    => $response->code,
        content => $self->decode(
            $response->decoded_content,
            ($response_headers->{'Content-Type'} || $content_type->{in})
        ),
        raw => $response->content,
    };

    unless ($response->is_success || $response->is_redirect) {
        $self->log("error: "
                . $response->status_line
                . $/
                . "message: "
                . $response->decoded_content)
            if $self->debug;

        $answer->{error} = "request failed: " . $response->status_line;
    }

    return $answer;
}

=head2 map_options

=cut

sub map_options {
    my ($self, $options, $command, $content_type) = @_;

    my $method = uc($command->{method} || $self->default_method);

    # check existence of mandatory attributes
    if ($command->{mandatory}) {
        $self->log("mandatory keys:\n" . dump(\@{ $command->{mandatory} }))
            if $self->debug;

        my @missing_attrs;
        if ($content_type =~ m/xml|json/) {
            foreach my $attr (@{ $command->{mandatory} }) {
                my @bits = split /\./, $attr;
                my $node = $options;
                push(@missing_attrs, $attr) unless
                    @bits == grep { ref $node eq "HASH" && exists $node->{$_} && ($node = $node->{$_} // {}) } @bits;
            }
        }
        else {
            foreach my $attr (@{ $command->{mandatory} }) {
                push(@missing_attrs, $attr) unless (exists $options->{$attr});
            }
        }

        return { error => 'mandatory attributes for this command missing: '
                . join(', ', @missing_attrs) }
            if @missing_attrs;
    }

    my %opts;

    # first include assumed to be already mapped default attributes
    %opts = %{ $command->{default_attributes} }
        if exists $command->{default_attributes};

    # then map everything in $options, overwriting detault_attributes if necessary
    if (keys %{ $self->mapping } and not $command->{no_mapping}) {
        $self->log("mapping hash:\n" . dump($self->mapping)) if $self->debug;

        # do the key and value mapping of options hash and overwrite defaults
        foreach my $key (keys %$options) {
            my ($newkey, $newvalue);
            $newkey = $self->mapping->{$key} if ($self->mapping->{$key});
            $newvalue = $self->mapping->{ $options->{$key} }
                if ($options->{$key} and $self->mapping->{ $options->{$key} });

            $opts{ $newkey || $key } = $newvalue || $options->{$key};
        }

        # and write everything back to $options
        $options = \%opts;
    }
    else {
        $options = { %opts, %$options };
    }

    # wrap all options in wrapper key(s) if requested
    $options =
        wrap($options, $command->{wrapper} || $self->wrapper, $content_type)
        unless ($method =~ m/^(GET|HEAD|DELETE)$/);

    $self->log("options:\n" . dump($options)) if $self->debug;

    return $options;
}

=head2 wrap

=cut

sub wrap {
    my ($options, $wrapper, $content_type) = @_;

    if (ref $wrapper eq 'ARRAY') {

        # XML needs wrapping into extra array ref layer to make XML::Simple
        # behave correctly
        if ($content_type =~ m/xml/) {
            $options = { $_ => [$options] } for (reverse @{$wrapper});
        }
        else {
            $options = { $_ => $options } for (reverse @{$wrapper});
        }
    }
    elsif (defined $wrapper) {
        $options = { $wrapper => $options };
    }

    return $options;
}

=head2 AUTOLOAD magic

=cut

sub AUTOLOAD {
    my ($self, %options) = @_;

    my ($command) = $AUTOLOAD =~ /([^:]+)$/;

    return { error => "unknown command: $command" }
        unless (exists $self->commands->{$command});

    my $options = \%options;

    # construct URI path
    my $uri  = URI->new($self->base_url);
    my $path = $uri->path;

    # keep for backward compatibility
    if ($self->commands->{$command}->{require_id}) {
        return { error => "required {id} attribute missing" }
            unless (exists $options->{id});
        my $id = delete $options->{id};
        $path .= '/' . $self->commands->{$command}->{pre_id_path}
            if (exists $self->commands->{$command}->{pre_id_path});
        $path .= '/' . $id;
        $path .= '/' . $self->commands->{$command}->{post_id_path}
            if (exists $self->commands->{$command}->{post_id_path});
    }
    elsif (exists $self->commands->{$command}->{path}) {
        $path .= '/' . $self->commands->{$command}->{path};

        # parse all mandatory ID keys from URI path
        # format: /path/with/some/:id/and/:another_id/fun.js
        my @mandatory = ($self->commands->{$command}->{path} =~ m/:(\w+)/g);

        # and replace placeholders
        foreach my $key (@mandatory) {
            return { error => "required {$key} attribute missing" }
                unless exists $options->{$key};

            my $encoded_option = uri_escape(delete $options->{$key});
            $path =~ s/:$key/$encoded_option/gex;
        }
    }
    else {
        $path .= "/$command";
    }

    $path .= '.' . $self->extension if ($self->extension);
    $uri->path($path);

    # configure in/out content types
    # order of precedence should be:
    # command based incoming_content_type
    # command based general content_type
    # content type based on extension (only for incoming)
    # global incoming_content_type
    # global general content_type
    my $content_type;
    $content_type->{in} =
           $self->commands->{$command}->{incoming_content_type}
        || $self->commands->{$command}->{content_type}
        || $CONTENT_TYPE{ $self->extension }
        || $self->incoming_content_type
        || $self->content_type;
    $content_type->{out} =
           $self->commands->{$command}->{outgoing_content_type}
        || $self->commands->{$command}->{content_type}
        || $self->outgoing_content_type
        || $self->content_type;

    # manage options
    $options = $self->map_options($options, $self->commands->{$command},
        $content_type->{in})
        if ((
                (keys %$options)
            and ($content_type->{out} =~ m/(xml|json|urlencoded)/))
        or (exists $self->commands->{$command}->{default_attributes})
        or (exists $self->commands->{$command}->{mandatory}));
    return $options if (exists $options->{error});

    # do the call
    my $response =
        $self->talk($self->commands->{$command}, $uri, $options, $content_type);

    $self->log("response:\n" . dump($response)) if $self->debug;

    return $response;
}

=head1 BUGS

Please report any bugs or feature requests on GitHub's issue tracker L<https://github.com/nupfel/Web-API/issues>.
Pull requests welcome.


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Web::API


You can also look for information at:

=over 4

=item * GitHub repository

L<https://github.com/nupfel/Web-API>

=item * MetaCPAN

L<https://metacpan.org/module/Web::API>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Web::API>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Web::API>

=back

=cut

1;    # End of Web::API

#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'Web::API' ) || print "Bail out!\n";
}

diag( "Testing Web::API $Web::API::VERSION, Perl $], $^X" );

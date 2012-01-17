#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'REST::Client::Simple' ) || print "Bail out!\n";
}

diag( "Testing REST::Client::Simple $REST::Client::Simple::VERSION, Perl $], $^X" );

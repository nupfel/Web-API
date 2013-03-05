use 5.010;
use inc::Module::Install;

name     'Web-API';
all_from 'lib/Web/API.pm';
author   q{Tobias Kirschstein <mail@lev.geek.nz>};
license  'perl';

build_requires 'Test::More';

requires 'Any::Moose';
requires 'LWP::UserAgent';
requires 'HTTP::Cookies';
requires 'Data::Dumper';
requires 'XML::Simple';
requires 'URI::Escape::XS';
requires 'JSON';
requires 'URI';
requires 'URI::QueryParam';
requires 'Carp';
requires 'Net::OAuth';
requires 'Data::Random';

auto_install;

WriteAll;

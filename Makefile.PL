use 5.010;
use inc::Module::Install;

name     'REST-Client-Simple';
all_from 'lib/REST/Client/Simple.pm';
author   q{Tobias Kirschstein <mail@lev.geek.nz>};
license  'perl';

build_requires 'Test::More';

requires 'Any::Moose';
requires 'REST::Client';
requires 'Data::Dumper';
requires 'XML::Simple';
requires 'URI::Escape::XS';
requires 'JSON';
requires 'URI';
requires 'Carp';

auto_install;

WriteAll;


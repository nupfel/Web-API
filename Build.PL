
use Module::Build;
use Module::Build::JSONMETA;

my $class = Module::Build->subclass( code => Module::Build::JSONMETA->code, );

my $build = $class->new(
    module_name => 'Web::API',
    license     => 'perl',
    dist_abstract =>
        'Web::API - A Simple base module to implement almost every RESTful API with just a few lines of configuration',
    requires => { perl => '5.10.1', }
);

$build->create_build_script;

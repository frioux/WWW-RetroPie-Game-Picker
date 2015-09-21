requires 'IO::All';
requires 'JSON::XS';
requires 'Web::Simple';
requires 'namespace::clean';

on test => sub {
   requires 'Test::More';
};

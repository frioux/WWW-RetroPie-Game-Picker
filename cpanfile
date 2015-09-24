requires 'IO::All';
requires 'JSON::XS';
requires 'namespace::clean';
requires 'Web::Simple';
requires 'Text::Xslate';

on test => sub {
   requires 'Test::More';
};

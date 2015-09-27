requires 'IO::All';
requires 'Cpanel::JSON::XS';
requires 'Config::Station';
requires 'namespace::clean';
requires 'Web::Simple';
requires 'Text::Xslate';
requires 'HTML::Zoom';

on test => sub {
   requires 'Test::More';
};

package WWW::RetroPie::Game::Picker::ConfigLoader;

use utf8;
use Moo;
use warnings NONFATAL => 'all';

use JSON::XS;
use IO::All;
use Try::Tiny;
use Module::Runtime 'use_module';
use namespace::clean;

has _debug => (
   is => 'ro',
   init_arg => undef,
   lazy => 1,
   default => sub {
      my $self = shift;

      exists $ENV{'DEBUG_' . $self->_env_key}
         ? $ENV{'DEBUG_' . $self->_env_key}
         : $self->__debug
   },
);

has __debug => (
   is => 'ro',
   init_arg => 'debug',
);

has _env_key => (
   is => 'ro',
   init_arg => 'env_key',
   required => 1,
);

has _location => (
   is => 'ro',
   init_arg => undef,
   lazy => 1,
   default => sub {
      my $self = shift;

      $ENV{$self->_env_key . '_CONFLOC'} || $self->__location
   },
);

has __location => (
   is => 'ro',
   init_arg => 'location',
   default => "$ENV{HOME}/.game-picker.json",
);

has _config_class => (
   is => 'ro',
   init_arg => 'config_class',
   required => 1,
);

sub _io { io->file(shift->_location) }

sub _debug_log {
   my ($self, $line, $ret) = @_;

   if ($self->_debug) {
      if (my @keys = keys %$ret) {
         warn "CONFIGLOADER FROM $line:\n";
         warn "  $_: $ret->{$_}\n" for @keys;
      } else {
         warn "CONFIGLOADER FROM $line: EMPTY\n";
      }
   }

   $ret
}

sub _read_config_from_file {
   my $self = shift;

   my $ret = try {
      $self->_debug_log(FILE => decode_json($self->_io->all));
   } catch {
      if ($self->_debug) {
         warn "CONFIGLOADER FROM FILE: $_\n"
      }
      {}
   };

}

sub _read_config_from_env {
   my $self = shift;

   my $k_re = '^' . quotemeta($self->_env_key) . '_(.+)';

   my $ret = +{
      map {; m/$k_re/; lc $1 => $ENV{$self->_env_key . "_$1"} }
      grep m/$k_re/,
      keys %ENV
   };

   $self->_debug_log(ENV => $ret);
}

sub _read_config {
   my $self = shift;

   {
      %{$self->_read_config_from_file},
      %{$self->_read_config_from_env},
   }
}

sub load {
   my $self = shift;

   use_module($self->_config_class)->new($self->_read_config)
}

sub store {
   my ($self, $obj) = @_;

   $self->_io->print(encode_json($obj->as_hash))
}

1;

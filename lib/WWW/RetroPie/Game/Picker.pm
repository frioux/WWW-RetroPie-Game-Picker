package WWW::RetroPie::Game::Picker;

use utf8;
use Web::Simple;
use warnings NONFATAL => 'all';
use autodie;

use IO::All;

use WWW::RetroPie::Game::Picker::ConfigLoader;

sub to_app { shift->to_psgi_app(@_) }

has _config => (
   is => 'ro',
   default => sub {
      WWW::RetroPie::Game::Picker::ConfigLoader->new(
         env_key => 'RPGP',
         config_class => 'WWW::RetroPie::Game::Picker::Config',
      )->load
   },
);

sub _redir { [ 302, [ content_type => 'text/html', location => $_[1] ], [ $_[2] ] ] }
sub _err { [ 500, [ content_type => 'text/html' ], [ $_[1] ]] }
sub _forbidden { [ 403, [ content_type => 'text/html' ], [ $_[1] ]] }
sub _conflict { [ 409, [ content_type => 'text/html' ], [ $_[1] ]] }

sub dispatch_request {
   my $self = shift;
   '/all/...' => sub {
      '/*/...' => sub {
         my ($system) = $_[1];

         return $self->_forbidden unless $system =~ m/^[\w]+$/;

         '/' => sub {
            my $html =
               join "\n",
               map qq(<li>$_ [<a href="/all/$system/$_/pick">Pick</a>]</li>),
               map $_->filename,
               io->dir($self->_config->real_roms_dir, $system)->all;

            return [ 200, [ content_type => 'text/html' ], [ "<html><ul>$html</ul></html>" ] ]
         },
         '/*/...' => sub {
            my ($game) = $_[1];

            my $real_path =
               io->file($self->_config->real_roms_dir, $system, $game)->name;

               return $self->_forbidden
                  if $game =~ m(/) || !-f $real_path;

            '/pick' => sub {
               my $dest_path =
                  io->file($self->_config->retropie_roms_dir, $system, $game)->name;

               return $self->_conflict('already in retropie dir!') if -e $dest_path;

               try {
                  symlink $real_path, $dest_path;

                  return $self->_redir("/all/$system/", 'Success!')
               } catch {
                  return $self->_err("Fail: $_");
               };
            },

         },
      },
      '/' => sub {
         my $html =
            join "\n",
            map qq(<li><a href="/all/$_/">$_</a></li>),
            map $_->filename,
            io->dir($self->_config->real_roms_dir)->all;

         return [ 200, [ content_type => 'text/html' ], [ "<html><ul>$html</ul></html>" ] ]
      },
   },
   '/selected/...' => sub {

      my $dir = $self->_config->retropie_roms_dir;
      '/*/...' => sub {
         my ($system) = $_[1];

         return $self->_forbidden unless $system =~ m/^[\w]+$/;

         '/' => sub {
            my $html =
               join "\n",
               map qq(<li>$_ [<a href="/selected/$system/$_/unpick">Unpick</a>]</li>),
               map $_->filename,
               io->dir($dir, $system)->all;

            return [ 200, [ content_type => 'text/html' ], [ "<html><ul>$html</ul></html>" ] ]
         },
         '/*/...' => sub {
            my ($game) = $_[1];

            my $path =
               io->file($dir, $system, $game)->name;

               return $self->_forbidden
                  if $game =~ m(/) || !-f $path;

            '/unpick' => sub {

               return $self->_err('unexpected symlink!')
                  unless readlink $path eq io->file($self->_config->real_roms_dir, $system, $game)->name;

               try {
                  unlink $path;

                  return $self->_redir("/selected/$system/", 'Success!')
               } catch {
                  return $self->_err("Fail: $_");
               };
            },

         },
      },
      '/' => sub {
         my $html =
            join "\n",
            map qq(<li><a href="/selected/$_">$_</a></li>),
            map $_->filename,
            io->dir($self->_config->retropie_roms_dir)->all;

         return [ 200, [ content_type => 'text/html' ], [ "<html><ul>$html</ul></html>" ] ]
      },
   },
}

1;

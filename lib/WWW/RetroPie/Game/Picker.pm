package WWW::RetroPie::Game::Picker;

use utf8;
use Web::Simple;
use warnings NONFATAL => 'all';
use autodie;

use IO::All;
use Text::Xslate;
use Config::Station;
use HTML::Zoom;

sub to_app { shift->to_psgi_app(@_) }

has _config => (
   is => 'ro',
   default => sub {
      Config::Station->new(
         env_key => 'RPGP',
         config_class => 'WWW::RetroPie::Game::Picker::Config',
      )->load
   },
);

sub _redir { [ 302, [ content_type => 'text/html', location => $_[1] ], [ $_[2] ] ] }
sub _err { [ 500, [ content_type => 'text/html' ], [ $_[1] ]] }
sub _forbidden { [ 403, [ content_type => 'text/html' ], [ $_[1] ]] }
sub _conflict { [ 409, [ content_type => 'text/html' ], [ $_[1] ]] }

has _xslate => (
   is => 'ro',
   lazy => 1,
   default => sub {
      Text::Xslate->new(
         path => ['var/tx'],
         type => 'text',
      )
   },
   handles => {
      _tx => 'render',
   },
);

sub _html_200 {
   my ($self, $t, $vars) = @_;

   [ 200, [ content_type => 'text/html' ], [ $self->_tx("$t.tx.html", $vars) ] ]
}

sub dispatch_request {
   my $self = shift;
   '/all/...' => sub {
      '/*/...' => sub {
         my ($system) = $_[1];

         return $self->_forbidden unless $system =~ m/^[\w]+$/;

         '/' => sub {
            my %links =
               map { readlink $_ => 1 }
               grep -l $_,
               map "$_",
               io->dir($self->_config->retropie_roms_dir, $system)->all;

            my @games = map +{
               name => $_->filename,
               linked => $links{$_->name}
            }, io->dir($self->_config->real_roms_dir, $system)->all;

            my $template = <<'HTML';
<html>
<body>
   <ul>
      <li id="games">
         <span class="game"></span> [
            <a class="unpick">Unpick</a>
         ]
      </li>
   </ul>
</body>
</html>
HTML
            my $fh = HTML::Zoom->from_html($template)
               ->select('#games')
               ->repeat_content([
                  map {
                     my $game = $_;
                     sub {
                        $_->select('.name')->replace_content($game->{name});
                        $_->select('.unpick')->add_to_attribute(
                           href => "/selected/$system/$game->{name}/pick"
                        );
                     }
                  } @games
               ])
               ->to_fh;
            [200, [content_type => 'text/html'], $fh ]
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
         my @systems =
            map $_->filename,
            io->dir($self->_config->real_roms_dir)->all;

         $self->_html_200('all_systems', { systems => \@systems })
      },
   },
   '/selected/...' => sub {

      my $dir = $self->_config->retropie_roms_dir;
      '/*/...' => sub {
         my ($system) = $_[1];

         return $self->_forbidden unless $system =~ m/^[\w]+$/;

         '/' => sub {
            my @games =
               map $_->filename,
               io->dir($dir, $system)->all;

            $self->_html_200('selected_games', {
               games => \@games,
               system => $system,
            });
         },
         '/*/...' => sub {
            my ($game) = $_[1];

            my $path =
               io->file($dir, $system, $game)->name;

               return $self->_forbidden
                  if $game =~ m(/) || !-e $path;

            '/unpick' => sub {

               return $self->_err('unexpected symlink!')
                  if !-l $path ||
                     readlink $path ne io->file($self->_config->real_roms_dir, $system, $game)->name;

               try {
                  unlink $path;

                  return $self->_redir("/selected/$system/", 'Success!')
               } catch {
                  return $self->_err("Fail: $_");
               };
            },

            '/delete' => sub {
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
         my @systems =
            map $_->filename,
            io->dir($self->_config->retropie_roms_dir)->all;

         $self->_html_200('selected_systems', { systems => \@systems })
      },
   },
   '/' => sub { $self->_html_200('index') },
}

1;

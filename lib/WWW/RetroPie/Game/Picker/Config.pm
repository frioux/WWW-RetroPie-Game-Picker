package WWW::RetroPie::Game::Picker::Config;

use utf8;
use Moo;
use warnings NONFATAL => 'all';

has real_roms_dir => (
   is => 'ro',
   default => sub { "$ENV{HOME}/roms" },
);

has retropie_roms_dir => (
   is => 'ro',
   default => sub { "$ENV{HOME}/RetroPie/roms" },
);

1;

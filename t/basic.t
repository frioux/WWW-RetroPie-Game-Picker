use 5.14.0;
use warnings;

use Test::More;
use File::Temp 'tempdir';
use HTTP::Request;
use IO::All;
use Plack::Test;

sub req { HTTP::Request->new(@_) }

use WWW::RetroPie::Game::Picker;

my $root = tempdir();
    $ENV{RPGP_REAL_ROMS_DIR} = my $src = "$root/src";
$ENV{RPGP_RETROPIE_ROMS_DIR} = my $dst = "$root/dst";

mkdir $src;
mkdir $dst;

mkdir "$_/snes" for $dst, $src;

io->file("$_/snes/already_exists")->touch for $src, $dst;
io->file("$src/snes/to_link")->touch;

symlink __FILE__, "$dst/snes/already_exists_x";

ok my $p = WWW::RetroPie::Game::Picker->new;
my $ua = Plack::Test->create($p->to_app);

subtest '/all/' => sub {
   {
      my $res = $ua->request(req(GET => '/all/'));

      like($res->decoded_content, '/snes/', '/all/');
   }

   {

      my $res = $ua->request(req(GET => '/all/../'));

      is($res->code, 403, '/all/$system/ is validated');
   }

   {
      my $res = $ua->request(req(GET => '/all/snes/'));

      like(
         $res->decoded_content,
         '/already_exists/',
         '/all/snes/ has /already_exists/',
      );
      like(
         $res->decoded_content,
         '/to_link/',
         '/all/snes/ has /to_link/',
      );
   }

   {
      ok(! -e "$dst/snes/to_link", 'not yet linked');

      my $res = $ua->request(req(GET => '/all/snes/to_link/pick'));

      is( $res->decoded_content, 'Success!', 'picking game works');
      is( $res->code, 302, 'Redirection');
      is( $res->header('Location'), '/all/snes/', '... to the right place');

      ok(-e "$dst/snes/to_link", 'linked');
   }

   {

      my $res = $ua->request(req(GET => '/all/snes/../pick'));

      is( $res->code, 403, 'Game validated');
   }

   {

      my $res = $ua->request(req(GET => '/all/snes/to_link/pick'));

      is( $res->code, 409, 'Cannot pick again');
   }

};

subtest '/selected/' => sub {
   {
      my $res = $ua->request(req(GET => '/selected/'));

      like($res->decoded_content, '/snes/', '/selected/');
   }

   {
      my $res = $ua->request(req(GET => '/selected/snes/'));

      like($res->decoded_content, '/to_link/', '/slected/ contains /to_link/');
   }

   {
      my $res = $ua->request(req(GET => '/selected/foo+bar/'));

      is($res->code, 403, '/selected/$system/ validated');
   }

   {
      ok( -e "$dst/snes/to_link", 'linked');
      my $res = $ua->request(req(GET => '/selected/snes/to_link/unpick'));

      is( $res->decoded_content, 'Success!', 'unpicking game works');
      is( $res->code, 302, 'Redirection');
      is( $res->header('Location'), '/selected/snes/', '... to the right place');
      ok(!-e "$dst/snes/to_link", 'unlinked');
   }

   {
      my $res = $ua->request(req(GET => '/selected/snes/herp/unpick'));

      is( $res->code, 403, 'unpicking validated');
   }

   {
      ok( -e "$dst/snes/already_exists", 'extant');
      my $res = $ua->request(req(GET => '/selected/snes/already_exists/unpick'));

      is( $res->code, 500, 'unpicking more validated');
      is( $res->decoded_content, 'unexpected symlink!', 'with useful message');
      ok( -e "$dst/snes/already_exists", 'still extant');
   }
};

done_testing;

END { io->dir($root)->rmtree }

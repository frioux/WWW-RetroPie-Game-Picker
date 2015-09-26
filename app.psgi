use 5.14.0;
use warnings;

use Plack::Builder;

use WWW::RetroPie::Game::Picker;

builder {
   enable "Deflater",
      content_type => ['text/css','text/html','text/javascript','application/javascript'],
      vary_user_agent => 1;

   WWW::RetroPie::Game::Picker->new->to_app;
};

use utf8;
use strict;
use warnings;
use FindBin qw/$Bin/;
use CGI::Compile;
use CGI::Emulate::PSGI;
use Plack::App::File;
use Plack::Builder;
use YAML::XS;
use App::AutoCRUD;


use lib "$Bin/lib";
use App::Flow::Controller::SearchJs;
use App::Flow::Controller::Root;


my $flow_config = YAML::XS::LoadFile("$Bin/flow_conf.yaml");
my $crud_config = YAML::XS::LoadFile("$Bin/crud_conf.yaml");


my $app = builder {
  mount "/flowdocs/search_flow.js" => App::Flow::Controller::SearchJs->new(config => $flow_config)->to_app;
  mount "/flow"                    => App::Flow::Controller::Root->new(config => $flow_config)    ->to_app;
  mount "/crud"                    => App::AutoCRUD->new(config => $crud_config)                  ->to_app;
  mount "/"                        => Plack::App::File->new(root => "$Bin/www/html/Documents")    ->to_app;
};


# Allow this script to be run also directly (without 'plackup'), so that
# it can be launched from Emacs
unless (caller) {
  require Plack::Runner;
  my $runner = Plack::Runner->new;
  $runner->parse_options(@ARGV);
  return $runner->run($app);
}


return $app;


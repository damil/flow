package App::Flow::Controller;
use utf8;
use strict;
use warnings;
use App::Flow::Context;
use DBI;
use parent 'Plack::Component';

use Plack::Util::Accessor qw(config);


sub call { # entry point for Plack::Component
  my ($self, $env) = @_;

  my $req = Plack::Request->new($env);
  my $c   = App::Flow::Context->new(req => $req, stash => {});

  $self->respond($c);
}


sub dbh_for {
  my ($self, $db_name) = @_;

  # get credentials from the YAML config file
  my $db_config = $self->config->{databases}{$db_name}
    or die "connect_db(): no config for database '$db_name'";
  my $connect_params = $db_config->{connect}
    or die "connect_db(): no config for '$db_name' has no 'connect' entry";

  # connect
  my $dbh = DBI->connect(@$connect_params)
    or die $DBI::errstr;

  return $dbh;
}


1;



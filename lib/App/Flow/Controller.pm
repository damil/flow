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

sub respond {
  my ($self) = @_;

  die ref($self) . "->respond() : should be implemented in the Controller subclass";
}



sub dbh_for {
  my ($self, $db_name) = @_;

  # get credentials from the config
  my $db_config = $self->config->{databases}{$db_name}
    or die "dbh_for(): no config for database '$db_name'";
  my $connect_params = $db_config->{connect}
    or die "dbh_for(): config for '$db_name' has no 'connect' entry";

  # connect
  my $dbh = DBI->connect(@$connect_params)
    or die $DBI::errstr;

  return $dbh;
}


1;


__END__

=encoding utf8

=head1 NAME

App::Flow::Controller - parent class for FLOW controllers

=head1 SYNOPSIS

  my $controller = App::Flow::Controller->new(config => $config_hash);

=head1 DESCRIPTION

Minimal class for FLOW controllers.

=head1 ATTRIBUTES

=head2 config

Reference to a config hash


=head1 METHODS

=head2 new

  my $controller = App::Flow::Controller->new(config => $config_hash);

Creates a new controller object.
The C<$config_hash> should have a C<databases> entry with L<DBI> connection
arguments for each database, i.e. something like the following YAML excerpt:

  databases:
    flow:
      connect:
        - dbi:Pg:dbname=flow;host=localhost;port=5432
        - username
        - password
        - { pg_enable_utf8: 1 }
    traduction_utf8:
      connect:
        - dbi:Pg:dbname=traduction_utf8;host=localhost;port=5432
        - username
        - password
        - { pg_enable_utf8: 1 }


=head2 call

  my $response = $controller->call($env);

This method is the entry point called by the L<Plack> application
to get a response for an HTTP request.

=head2 respond

  my $response = $controller->respond($plack_request);

This method MUST be implemented in subclasses for responding to HTTP requests.

=head2 dbh_for

  my $dbh = $controller->dbh_for('flow');

Returns a L<DBI> handle to the specified database.
Credentials for the connection are taken from the config hash, as explained above.

=head1 AUTHOR

Laurent Dami, E<lt>dami AT cpan DOT org<gt>, June 2023.

=head1 COPYRIGHT AND LICENSE

Copyright 2023 by Laurent Dami.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

package App::Flow::Context;
use utf8;
use strict;
use warnings;
use URI::QueryParam;
use Plack::Util::Accessor qw(req stash);

sub new {
  my ($class, @args) = @_;

  my $self = bless {@args}, $class;
}

sub param {
  my ($self, $p) = @_;
  return $self->req->parameters->get($p);
}

sub new_uri {
  my $self = shift;

  # query params : may be given either as a hash or as a hashref (esp. when called from Template Toolkit)
  my $query_params = ref $_[0] ? $_[0] : {@_};

  my $uri = $self->req->uri;
  $uri->query_param($_ => $query_params->{$_}) foreach keys %$query_params;
  return $uri->as_string;
}

sub add_into_stash {
  my ($self, %args) = @_;
  $self->{stash}{$_} = $args{$_} foreach keys %args;
}




1;



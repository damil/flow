package App::Flow::Context;
use utf8;
use strict;
use warnings;
use URI::QueryParam;
use Plack::Util::Accessor qw(req stash config);

sub new {
  my ($class, @args) = @_;

  my $self = bless {@args}, $class;
  defined $self->{req} && $self->{req}->isa('Plack::Request')
    or die __PACKAGE__ . "->new(req => ...) : req should be a Plack::Request object";
  $self->{$_} //= {} for qw/stash config/;
  return $self;
}

sub param {
  my ($self, $p) = @_;
  return $self->req->parameters->get($p);
}

sub new_uri {
  my $self = shift;

  # query params : may be given either as a hash or as a hashref (esp. when called from Template Toolkit)
  my $query_params = ref $_[0] ? $_[0] : {@_};

  # override scheme and authority if config requires it
  my $uri = $self->req->uri;
  $_ and $uri->scheme($_)    for $self->config->{base_href}{scheme};
  $_ and $uri->authority($_) for $self->config->{base_href}{authority};

  # override query params
  $uri->query_param($_ => [])                  foreach qw/rank id alph/;
  $uri->query_param($_ => $query_params->{$_}) foreach keys %$query_params;

  return $uri->as_string;
}

sub add_into_stash {
  my ($self, %args) = @_;
  $self->{stash}{$_} = $args{$_} foreach keys %args;
}

1;

__END__

=encoding utf8

=head1 NAME

App::Flow::Context - context information for a single request

=head1 SYNOPSIS

  my $context = App::Flow::Context->new(req => $a_plack_request, stash => {});
  
  $context->add_into_stash(abc => 123);
  my $param_x = $context->param('x');
  my $uri     = $context->new_uri(foo => 'bar', cancel_this_param => []);

=head1 DESCRIPTION

Minimal class for holding the context of a single HTTP request.

=head1 ATTRIBUTES

=head2 req

Reference to the L<Plack::Request> object.

=head2 stash

Hash for storing temporary data relevant for the current request.

=head1 METHODS

=head2 new

  my $context = App::Flow::Context->new(req => $a_plack_request, stash => {foo => 'bar'});

Creates a new context object.
Args supplied to the constructor are stored within the internal object hash.
The C<req> arg is mandatory and should be a L<Plack::Request> object.

=head2 param

  my $val = $context->param('key');

Proxy method to L<Hash::Multivalue/get>.
Returns the scalar HTTP value of the given key.

=head2 new_uri

  my $uri = $context->new_uri(foo => 'bar', cancel_this_param => []);

Returns a new L<URI> object built from current HTTP request, including path_info and query parameters.
Parameters passed to the method call will be added or will override existing parameters.
To cancel an existing parameter, pass an empty arrayref as value.

=head2 add_into_stash

  $context->add_into_stash(abc => 123, def => 456);

Proxy method for adding entries into C<< $context->stash >>.


=head1 AUTHOR

Laurent Dami, E<lt>dami AT cpan DOT org<gt>, June 2023

=head1 COPYRIGHT AND LICENSE

Copyright 2023 by Laurent Dami.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

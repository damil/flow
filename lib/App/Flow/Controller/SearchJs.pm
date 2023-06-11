package App::Flow::Controller::SearchJs;
use utf8;
use strict;
use warnings;
use Text::Transliterator::Unaccent;
use JSON::XS;

use parent 'App::Flow::Controller';


sub respond {
  my ($self, $c) = @_;

  # requête HTTP
  my $xlang = $c->param('lang') || 'en';

  # génération de la réponse -- contenu valide pendant 30 min.
  my $res = $c->req->new_response(200);
  $res->content_type('text/javascript; charset=UTF-8');
  $res->header(expire => time + 1800);

  # requêtes en base
  my $dbh = $self->dbh_for('flow');

  my $full_names = $dbh->selectall_arrayref(<<_EOSQL_);
     SELECT nc.index, nc.orthographe, 
            CASE WHEN (SELECT ordre FROM rangs WHERE index = nc.ref_rang) 
                    > (SELECT ordre FROM rangs WHERE en = 'genus') 
                 THEN nc.autorite 
                 ELSE coalesce(nc.autorite, '') || coalesce(' (' || 
                      (SELECT orthographe FROM noms WHERE index = 
                          (SELECT ref_nom_parent FROM noms WHERE index = nc.index)) 
                      || ')', '')
            END 
      FROM noms_complets AS nc 
      LEFT JOIN rangs AS r ON nc.ref_rang = r.index 
      WHERE r.en not in ('order', 'suborder') ORDER BY nc.orthographe
_EOSQL_

  my $authors = $dbh->selectall_arrayref(<<_EOSQL_);
     SELECT index, coalesce(nom || ' ', '') || coalesce(prenom, '') AS auteur from auteurs
_EOSQL_

  my $countries = $dbh->selectall_arrayref(<<_EOSQL_);
     SELECT index, $xlang from pays where index in (SELECT DISTINCT ref_pays FROM taxons_x_pays)
_EOSQL_

  # suppression des accents pour les auteurs et les pays
  my $unaccenter = Text::Transliterator::Unaccent->new;
  $unaccenter->($_->[1]) foreach @$authors, @$countries;


  # génération au format JSON
  my $json_coder = JSON::XS->new->utf8->pretty;
  my $mk_json = sub {
    my ($name, $rows) = @_;
    return "${name}ids=" . $json_coder->encode([map {$_->[0]} @$rows]) . ";\n"
         . "${name}="    . $json_coder->encode([map {$_->[1]} @$rows]) . ";\n"
  };
  my $json = $mk_json->(noms_complets => $full_names)
           . "authors=" . $json_coder->encode([map {$_->[2]} @$full_names]) . ";\n"
           . $mk_json->(auteurs       => $authors)
           . $mk_json->(pays          => $countries);

  # renvoi de la réponse
  $res->body($json);
  return $res->finalize;
}


1;


__END__

=encoding utf8

=head1 NAME

App::Flow::Controller::SearchJS - dynamic generation of 'search_flow.js' content

=head1 SYNOPSIS

  my $app = builder { # using Plack::Builder
    mount "/flowdocs/search_flow.js" => App::Flow::Controller::SearchJs->new(config => $flow_config)->to_app;
  }

=head1 DESCRIPTION

FLOW controller for dynamic generation of 'search_flow.js' content.

This controller connects to the FLOW database and builds javascript content to be used by FLOW autocompleters.
Algorithms were copied from the (very) old CGI scripts of the original FLOW implementation.

The following javascript arrays are generated :


=over

=item noms_complets

Taken from a join between tables 'noms_complets' and 'rangs'.

=item authors

Taken from a join between tables 'noms_complets' and 'rangs'.

=item auteurs

Taken from the 'auteurs' table.

=item pays

Taken from the 'pays' table.

=back

=head1 AUTHOR

Laurent Dami, E<lt>dami AT cpan DOT org<gt>, June 2023.

=head1 COPYRIGHT AND LICENSE

Copyright 2023 by Laurent Dami.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

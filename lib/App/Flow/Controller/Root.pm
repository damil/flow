package App::Flow::Controller::Root;
use 5.30.0;
use utf8;
use strict;
use warnings;
use Template;
use Encode qw/encode_utf8/;

use parent 'App::Flow::Controller';


sub respond {
  my ($self, $c) = @_;

  # objet pour la réponse
  my $res = $c->req->new_response(200);
  $res->content_type('text/html; charset=UTF-8');

  # fonction de traduction 
  my $xlang         = $c->param('lang') || 'en';
  my $dbh_traduc    = $self->dbh_for('traduction_utf8');
  my $traductions   = $dbh_traduc->selectall_hashref("SELECT id, $xlang FROM traductions", "id");
  my $traduc        = sub {my $id = shift; return $traductions->{$id}{$xlang} || $id};

  # dernière mise à jour de la base
  my $dbh           = $self->dbh_for('flow');
  my ($last_update) = $dbh->selectrow_array("SELECT modif FROM synopsis");


  # données de stash qui seront passées au template
  $c->add_into_stash(
    xlang              => $xlang,
    xbase              => $c->param('db')          || 'flow',
    xpage              => $c->param('page')        || 'home',
    searchtable        => $c->param('searchtable') || 'noms_complets',
    searchid           => $c->param('searchid'),
    photos             => $self->config->{photos_carrousel},
    traduc             => $traduc,
    last_update        => $last_update,
   );

  # données de stash ajoutées dans un 2ème temps car elles ont besoin du stash initial
  $c->add_into_stash(
    lang_descriptions  => $self->compute_lang_descriptions($c),
    search_types       => $self->compute_search_types($c),
    icon_descriptions  => $self->compute_icon_descriptions($c),
    icon2_descriptions => $self->compute_icon2_descriptions($c),
    bottom_cols        => $self->compute_bottom_cols($c),
   );



  # génération du HTML à travers le template
  my $tmpl = Template->new({INCLUDE_PATH => 'd:/Git/DAMI/flow/src/tmpl'});
  $tmpl->process("root.tt2", {c => $c, $c->stash->%*}, \my $html)
    or die $tmpl->error;

  # renvoi de la réponse
  $res->body(encode_utf8($html));
  return $res->finalize;
}









sub compute_lang_descriptions { # drapeaux pour les différents langages du site
  my ($self, $c) = @_;

  my @lang_descriptions = list_of_records(
    [id => name       => 'img'   ],   # headers
  #  ==    ====           ===         # data rows below
    [en => English    => 'en.gif'],
    [fr => French     => 'fr.gif'],
    [es => Spanish    => 'es.png'],
    [de => German     => 'de.png'],
    [zh => Chinese    => 'zh.png'],
    [pt => Portuguese => 'br.png'], # Brazilian flag instead of Pt
   );
  $_->{display} = $_->{id} eq $c->stash->{xlang} ? 'block' : 'none' foreach @lang_descriptions;

  return \@lang_descriptions;
}


sub compute_search_types {
  my ($self, $c) = @_;

  my %search_type_names = (
  	'noms_complets' => $c->stash->{traduc}->('sciname'),
  	'auteurs'       => $c->stash->{traduc}->('author'),
  	'pays'          => $c->stash->{traduc}->('country'),
  );
  my @sorted_search_types = sort {$search_type_names{$a} cmp $search_type_names{$b}} keys %search_type_names;

  return [map { {id => $_, name => $search_type_names{$_}} } @sorted_search_types];
}



sub compute_icon_descriptions { # icônes centrales en haut de page
  my ($self, $c) = @_;

  my @icon_descriptions = list_of_records(
    [name          => traduc         =>  alt                        => 'img'                ],
  #  =====            ======             ===                            ===
    [families      => families       => 'Families'                  => 'Fam.png'            ],
    [genera        => genera         => 'Genera'                    => 'Gen.png'            ],
    [speciess      => speciess       => 'Species'                   => 'Spe.png'            ],
    [names         => names          => 'Names'                     => 'Nam.png'            ],
    [vernaculars   => vernaculars    => 'Vernaculars'               => 'Ver.png'            ],
    [publications  => publications   => 'Publications'              => 'pub.png'            ],
    [authors       => authors        => 'Authors'                   => 'author.png'         ],
    [countries     => countries      => 'Geographical distribution' => 'world.png'          ],
    [associates    => bioInteract    => 'Associated taxa'           => 'plant.png'          ],
    [cavernicolous => cavernicolous  => 'Cavernicolous'             => 'carvernicolous.png' ], # typo in the png filename
    [fossils       => fossils        => 'Fossils'                   => 'ere.png'            ],
    [images        => images         => 'Images'                    => 'photos.png'         ],
    [repositories  => repositories   => 'Repositories'              => 'deposit.png'        ],
    [board         => board          => 'Synopsis'                  => 'synopsis.png'       ],
    [updates       => lastUpdates    => 'Updates'                   => 'updates.png'        ],
    [classif       => classification => 'Classification'            => 'logo_classif.png'   ],
    [molecular     => molecular_data => 'Molecular data'            => 'molecule_flow.png'  ],
   );


  # ajout des hyperliens
  $_->{href} = $c->new_uri(page => 'explorer', card => $_->{name}) foreach @icon_descriptions;

  return \@icon_descriptions;
}



sub compute_icon2_descriptions { # icônes à droite en haut de page
  my ($self, $c) = @_;

  my @icon2_descriptions = list_of_records(
    [name          => traduc       => alt             => img           => 'href'                        ],
  #  ====             ======          ===                ===               ====
    [contact       => contact      => 'contact'       => 'contact.png' => $self->contact_href($c)       ],
    [projectFLOW   => aboutProject => 'Project'       => 'project.png' => $c->new_uri(page => 'project')],
    [fulgoromorpha => fulgoromopha => 'Fulgoromorpha' => 'fulgo.png'   => $c->new_uri(page => 'intro')  ],
  );

  return \@icon2_descriptions;
}



sub compute_bottom_cols {
  my ($self, $c) = @_;

  my @link_headers = qw(   txt                     href                                      target);
  #                        ===                     ====                                      ======
  my @bottom_cols = (

    ['Home'            => [[FLOW               => "http://hemiptera.infosyslab.fr/flow/"             ],
                           [HemDBases          => "http://hemiptera.infosyslab.fr/"       => '_blank'],
                           [DBTNT              => "http://hemiptera.infosyslab.fr/dbtnt/" => '_blank']]],
    ['Taxonomy'        => [[families           => $c->new_uri(page => 'families')                    ],
                           [genera             => $c->new_uri(page => 'genera')                      ],
                           [speciess           => $c->new_uri(page => 'speciess')                    ]]],
    ['Names'           => [[names              => $c->new_uri(page => 'names')                       ],
                           [vernaculars        => $c->new_uri(page => 'vernaculars')                 ]]],
    ['Classifications' => [[classification     => $c->new_uri(page => 'classification')              ],
                           [phylogeny          => '#'                                                ]]],
    ['Associated data' => [[countries          => $c->new_uri(page => 'countries')                   ],
                           [bioInteract        => $c->new_uri(page => 'associates')                  ],
                           [fossils            => $c->new_uri(page => 'fossils')                     ],
                           [images             => $c->new_uri(page => 'images')                      ],
                           [repositories       => $c->new_uri(page => 'repositories')                ]]],
    ['Bibliography'    => [[publications       => $c->new_uri(page => 'publications')                ],
                           [authors            => $c->new_uri(page => 'authors')                     ]]],
    ['General'         => [[aboutProject       => $c->new_uri(page => 'project')                     ],
                           [Fulgoromorpha      => $c->new_uri(page => 'intro')                       ],
                           [board              => $c->new_uri(page => 'explorer', card => 'board')   ],
                           [lastUpdates        => $c->new_uri(page => 'explorer', card => 'updates') ]]],
    ['Follow FLOW'     => [[Twitter            => "https://twitter.com/FLOWwebsite"       => '_blank'],
                           [Facebook           => "https://www.facebook.com/FLOWwebsite"  => '_blank'],
                           [contact            => $self->contact_href($c)                            ]]],
   );

  my @cols = map { {title => $_->[0], links => [list_of_records(\@link_headers, @{$_->[1]})]} } @bottom_cols;

  return \@cols;
}


sub contact_href {
  my ($self, $c) = @_;

  # données de contact en provenance de la config
  my $contact_info = $self->config->{contact}
    or die "no 'contact' entry in config";

  # construction du lien href
  my $contact_href = sprintf "mailto:%s?subject=%s&body=%s", @{$contact_info}{qw/email subject body/};

  # rajout de l'indication de quelle page vient l'utilisateur
  my @uri_args;
  @uri_args = (page => 'explorer', card => 'searching', searchtable => 'noms_complets', reload => 1)
    if $c->param('searchid');
  $contact_href .= "\n" . $c->new_uri(@uri_args);

  # échappement des sauts de ligne
  $contact_href =~ s/\n/%0A/g;

  return $contact_href;
}






#======================================================================
# FONCTIONS UTILITAIRES (pas des méthodes!)
#======================================================================

sub list_of_records {
  my ($headers, @rows) = @_;
  return map {my %record; @record{@$headers} = @$_; \%record} @rows;
}



1;

__END__



my $url = url();



Delete('searchid');



# traductions
my $config_file = "$ENV{FLOW_CONFDIR}/flow/flowexplorer.conf";

my $config = get_connection_params($config_file);



my $docfullpath = "$ENV{FLOW_SRCDIR}/html/Documents/flowdocs/";


my $searchjs = $docfullpath.$config->{'SEARCHJS'};








my $search_id  = ucfirst($traduction->{search}->{$xlang});


my $typdef = $searchtable;

my %attributes = (
	'noms_complets' => {'class'=>'searchOption'},
	'auteurs'       => {'class'=>'searchOption'},
	'pays'          => {'class'=>'searchOption'},
);

my $search = url_param('search') || '';
for (my $i = 1; $i < scalar(keys(%types)) + 1; $i++) {
	my $schstr = param("search$i");
	if (ucfirst($schstr) ne ucfirst($traduction->{search}->{$xlang})) { $search = $schstr; }
}





#======================================================================
# Carrousel de photos
#======================================================================



## LE CONTENU ##################################
my $card = url_param('card') || '';



my @argus;
foreach (url_param()) { if ($_ ne 'lang') { push(@argus, $_.'='.url_param($_)) } }

my $logo = a({-href=>"$url?db=$xbase&page=home&lang=$xlang", -style=>'text-decoration: none;'}, img({-src=>$docpath.'logoFLOW.png', -alt=>"FLOW", -style=>'border: 0;', -height=>'46px'}));











sub classification {
	my $conf = get_connection_params("$ENV{FLOW_CONFDIR}/flow/classif.conf");
	my $dbh = db_connection($conf);
	my $trans = read_lang($conf);
	my $order = request_tab("SELECT n.index, orthographe, fossil FROM noms AS n LEFT JOIN rangs AS r ON n.ref_rang = r.index WHERE r.en = 'order';", $dbh, 2);
	my $classif .= span({-style=>'margin-left: 20px;'},$order->[0][1]) . br;
	my $suborders = request_tab("SELECT n.index, orthographe, fossil FROM noms AS n LEFT JOIN rangs AS r ON n.ref_rang = r.index WHERE n.ref_nom_parent = $order->[0][0] ORDER BY orthographe;", $dbh, 2);

	foreach my $suborder (@{$suborders}) {
		my $nom = $suborder->[1];
		if ($suborder->[2]) { $nom .= 'Â†' }
		$classif .= span({-style=>'margin-left: 40px;'},$nom) . br;
		my $infraorders = request_tab("SELECT n.index, orthographe, fossil, r.en FROM noms AS n LEFT JOIN rangs AS r ON n.ref_rang = r.index WHERE n.ref_nom_parent = $suborder->[0] ORDER BY orthographe;", $dbh, 2);

		foreach my $infraorder (@{$infraorders}) {
			if ($infraorder->[3] eq 'infraorder') {
				$nom = $infraorder->[1];
				if ($infraorder->[2]) { $nom .= 'Â†' }
				$classif .= span({-style=>'margin-left: 60px;'},$nom) . br;
				my $sons = request_tab("SELECT n.index, orthographe, fossil, r.en FROM noms AS n LEFT JOIN rangs AS r ON n.ref_rang = r.index WHERE n.ref_nom_parent = $infraorder->[0] ORDER BY orthographe;", $dbh, 2);
				foreach my $son (@{$sons}) {
					if ($son->[3] eq 'super family') {
						$nom = $son->[1];
						if ($son->[2]) { $nom .= 'Â†' }
						$classif .=span({-style=>'margin-left: 80px;'},$nom) . br;
						my $families = request_tab("SELECT n.index, orthographe, fossil, r.en FROM noms AS n LEFT JOIN rangs AS r ON n.ref_rang = r.index WHERE n.ref_nom_parent = $son->[0] ORDER BY orthographe;", $dbh, 2);
						foreach my $family (@{$families}) {
							$nom = $family->[1];
							if ($family->[2]) { $nom .= 'Â†' }
							$classif .= span({-style=>'margin-left: 100px;'},$nom) . br;
						}
					}
					elsif ($son->[3] eq 'family') {
						$nom = $son->[1];
						if ($son->[2]) { $nom .= 'Â†' }
						$classif .= span({-style=>'margin-left: 100px;'},$nom) . br;
					}
				}
			}
			elsif ($infraorder->[3] eq 'super family') {
				$nom = $infraorder->[1];
				if ($infraorder->[2]) { $nom .= 'Â†' }
				$classif .= span({-style=>'margin-left: 80px;'},$nom) . br;
				my $families = request_tab("SELECT n.index, orthographe, fossil, r.en FROM noms AS n LEFT JOIN rangs AS r ON n.ref_rang = r.index WHERE n.ref_nom_parent = $infraorder->[0] ORDER BY orthographe;", $dbh, 2);
				foreach my $family (@{$families}) {
					$nom = $family->[1];
					if ($family->[2]) { $nom .= 'Â†' }
					$classif .= span({-style=>'margin-left: 100px;'},$nom) . br;
				}
			}
		}
	}

	$classif .= p . span({-style=>'margin-left: 20px;'},"Incertae sedis") . br;
	my $incertae = request_tab("SELECT n.index, orthographe, fossil FROM noms AS n LEFT JOIN rangs AS r ON n.ref_rang = r.index WHERE r.en = 'incertae sedis' ORDER BY orthographe;", $dbh, 2);

	foreach my $insed (@{$incertae}) {
		my $nom = $insed->[1];
		if ($insed->[2]) { $nom .= 'Â†' }
		$classif .= span({-style=>'margin-left: 40px;'},$nom) . br;
	}

	my $content = h2({-style=>'margin-left: 20px'}, "Hemiptera classification"). br. $classif;
}


#!/usr/bin/perl

use strict;
use CGI qw/:standard/;
use DBCommands qw (get_connection_params db_connection request_hash request_tab request_row get_title);
use URI::Escape;
use JSON::XS;
use Text::Transliterator::Unaccent;


my $url = url();


# variables de navigation
my $xbase       = url_param('db')      || 'flow';
my $xpage       = url_param('page')    || 'home';
my $xlang       = url_param('lang')    || 'en';

my $searchtable = param('searchtable') || 'noms_complets';
my $searchid    = param('searchid');
Delete('searchid');
my $docpath     = '/flowdocs/';


my $pagetitle = "FLOW Website";

# traductions
my $config_file = "$ENV{FLOW_CONFDIR}/flow/flowexplorer.conf";

my $config = get_connection_params($config_file);

my $traduction = read_lang($xlang);

my $dbc = DBCommands->connect_db('flow');

my $last_update = request_row("SELECT modif FROM synopsis;",$dbc);

my $docfullpath = "$ENV{FLOW_SRCDIR}/html/Documents/flowdocs/";


my $searchjs = $docfullpath.$config->{'SEARCHJS'};

my %search_type_names = (
	'noms_complets' => $traduction->{sciname}->{$xlang},
	'auteurs'       => $traduction->{author}->{$xlang},
	'pays'          => $traduction->{country}->{$xlang},
);
my @sorted_search_types = sort {$search_type_names{$a} cmp $search_type_names{$b}} keys %search_type_names;
my @search_types = map { {id => $_, name => $search_type_names{$_}} } @sorted_search_types;







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

my @photos = ('Tropiduchidae',
              'Tropiduchidae 2',
              'Trienopa typica',
              'Tettigometra laeta',
              'Tachycixius venustulus',
              'Reptalus panzeri',
              'Ranissus egerneus',
              'Pterodictya reticularis',
              'Plectoderes scapularis',
              'Plectoderes flavovittata',
              'Phrictus cf tripartitus',
              'Phrictus cf tripartitus 2',
              'Parorgerius platypus',
              'Ormenis sp',
              'Omolicna sp',
              'Oeclidius browni',
              'Odontoptera carrenoi',
              'Noabennarella costaricensis',
              'Meenoplus albosignatus',
              'Lappida sp',
              'Issidae',
              'Hemisphaerius sp',
              'Fulgoroidea',
              'Fulgoroidea 2',
              'Fulgora cf laternaria 2',
              'Fulgora cf laternaria 1',
              'Flatidae',
              'Fipsianus andreae',
              'Eurybregma nigrolineata',
              'Epibidis sp',
              'Enchophora prasina',
              'Dictyophara europaea rosea',
              'Dictyophara europaea 2',
              'Dictyophara europaea 1',
              'Derbidae',
              'Dendrokara monstrosa 2',
              'Dendrokara monstrosa 1',
              'Conomelus lorifer',
              'Cixiidae',
              'Chlorionidea flava',
              'Carthaeomorpha rufipes',
              'Caliscelis bonellii',
              'Asiraca clavicornis',
              'Anotia sp');


#======================================================================



## LE CONTENU ##################################
my $card = url_param('card') || '';



my @argus;
foreach (url_param()) { if ($_ ne 'lang') { push(@argus, $_.'='.url_param($_)) } }

my $logo = a({-href=>"$url?db=$xbase&page=home&lang=$xlang", -style=>'text-decoration: none;'}, img({-src=>$docpath.'logoFLOW.png', -alt=>"FLOW", -style=>'border: 0;', -height=>'46px'}));



#======================================================================
# drapeaux pour les différents langages du site
#======================================================================
my @lang_descriptions = list_of_records(
  [id => name       => 'img'   ],   # headers
#  ==    ====           ===         # data rows below
  [en => English    => 'en.png'],
  [fr => French     => 'fr.png'],
  [es => Spanish    => 'es.png'],
  [de => German     => 'de.png'],
  [zh => Chinese    => 'zh.png'],
  [pt => Portuguese => 'br.png'], # Brazilian flag instead of Pt
 );
$_->{display} = $_->{id} eq $xlang ? 'block' : 'none' foreach @lang_descriptions;


#======================================================================
# icônes centrales en haut de page
#======================================================================
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
$_->{href} = "$rooturl/flow?db=$xbase&page=explorer&card=$_->{name}&lang=$xlang" foreach @icon_descriptions;


#======================================================================
# icônes à droite en haut de page
#======================================================================
my $msg_email = 'thierry.bourgoin@mnhn.fr';
my $msg_ref   = $searchid
  ? "$rooturl/flow?db=flow&page=explorer&card=searching&searchid=$searchid&searchtable=noms_complets&lang=en&reload=1"
  : "TODO SELF_URL(-path_info=>1,-query=>1)";
}
my $msg_body = <<_EOMSG_;
  Thank you for using FLOW. 
  You want to report a problem with this page or you want to complete the data:
  any complementary information/data and correction are very welcome, but only published ones can be considered.
  So please provide the references of your sources.
  $msg_ref
_EOMSG_
my $contact_href = "mailto:$msg_email&subject=FLOW improvement&body=$msg_body";


my @icon2_descriptions = list_of_records(
  [name          => traduc       => alt             => img           => 'href'                                       ],
#  ====             ======          ===                ===               ====
  [contact       => contact      => 'contact'       => 'contact.png' => $contact_href                                ],
  [projectFLOW   => aboutProject => 'Project'       => 'project.png' => "$rooturl?db=$xbase&page=project&lang=$xlang"],
  [fulgoromorpha => fulgoromopha => 'Fulgoromorpha' => 'fulgo.png'   => "$rooturl?db=$xbase&page=intro&lang=$xlang"  ],
);

#======================================================================
# liens en bas de page
#======================================================================


my $link_page = sub {my $card = shift; return "$rooturl?db=$xbase&page=$card&lang=$xlang"}

my @link_headers = qw(   txt                     href                                      target);
#                        ===                     ====                                      ======
my @bottom_cols = (

  ['Home'            => [[FLOW               => "http://hemiptera.infosyslab.fr/flow/"                     ],
                         [HemDBases          => "http://hemiptera.infosyslab.fr/"       => '_blank'        ],
                         [DBTNT              => "http://hemiptera.infosyslab.fr/dbtnt/" => '_blank'        ]],
  ['Taxonomy'        => [[families           => $link_page->('families')                                   ],
                         [genera             => $link_page->('genera')                                     ],
                         [speciess           => $link_page->('speciess')                                   ]],
  ['Names'           => [[names              => $link_page->('names')                                      ],
                         [vernaculars        => $link_page->('vernaculars')                                ]],
  ['Classifications' => [[classification     => $link_page->('classification')                             ],
                         ['#'                => $link_page->('phylogeny')                                  ]],
  ['Associated data' => [[countries          => $link_page->('countries')                                  ],
                         [bioInteract        => $link_page->('associates')                                 ],
                         [fossils            => $link_page->('fossils')                                    ],
                         [images             => $link_page->('images')                                     ],
                         [repositories       => $link_page->('repositories')                               ]],
  ['Bibliography'    => [[publications       => $link_page->('publications')                               ],
                         [authors            => $link_page->('authors')                                    ]],
  ['General'         => [[aboutProject       => $link_page->('project')                                    ],
                         [Fulgoromorpha      => $link_page->('intro')                                      ],
                         [board              => "$rooturl?db=$xbase&page=explorer&card=board&lang=$xlang"  ],
                         [lastUpdates        => "$rooturl?db=$xbase&page=explorer&card=updates&lang=$xlang"]],
  ['Follow FLOW'     => [[Twitter            => "https://twitter.com/FLOWwebsite"       => '_blank'        ],
                         [Facebook           => "https://www.facebook.com/FLOWwebsite"  => '_blank'        ],
                         [contact            => $contact_href                                              ]],
);




sub list_of_records {
  my ($headers, @rows) = @_;
  return map {my %record; @record{@$headers} = @$_; \%h} @rows;
}



sub read_lang {
	my ( $xlang ) = @_;

	if ( my $dbc = DBCommands->connect_db('traduction_utf8')) {
		my $tr = $dbc->selectall_hashref("SELECT id, $xlang FROM traductions;", "id");
		$dbc->disconnect;
		return $tr;
	}
	else {
		my $error_msg .= $DBI::errstr;
		print 	header('Error'),
			h1("Database connection error"),
			pre($error_msg),p;

		return undef;
	}
}

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



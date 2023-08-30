# /!\ IN PROGRESS, don't trust this file to work as is!

# This is a Perl conversion of autotexts.php, which generate a "synopsis" (ie data presentation as a redacted text) of a given taxon from FLOW.

package App::Flow::Controller::Autotext;
use utf8;
use strict;
use warnings;

use DBI;
use Getopt::Long;

use Template;
use Encode         qw/encode_utf8/;
use Capture::Tiny  qw/capture_stdout/;
use App::Flow::Controller::Explorer;
use parent 'App::Flow::Controller';
use Plack::Util::Accessor qw(root_dir); # being unfamiliar with Perl pachages, I hust cut-and-pasted from other files until it worked; I'd be surprised if modules couldn't be cut or added.


# I don't know enough about Perl coding and FLOW's architecture to know how to transfer information from a file to another.
# Hence, a certain number of placeholders have been used; I humbly asks Laurent to establish the proper links so that this appears within the FLOW website.


# /!\ NOTE FOR FUTURE CODERS: the database FLOW have functions that may be useful to streamline future coding; I found this out a bit late to make full use of it, but perhaps you could!
# Also, consider implementing checks for undefined values in FLOW.


my $id_main_taxon = '5077'; # /!\ PLACEHOLDERS: this should be got from Getopt

# /!\ PLACEHOLDERS (hence its placement here): proper connection would, of course, pull the relevant parameters from the config file.
	sub crude_connection {
		if ( my $connect = DBI->connect("DBI:Pg:dbname=flow;host=localhost;port=5432","postgres","pgadmin",{pg_enable_utf8 => 1}) ){
				return ($connect);
			}
			else { # connection failed
				my $error_msg = $DBI::errstr;
				die $error_msg;
			}
		}

	
# declaration of the variables used to store data pulled from FLOW; they could be declared later, but these also act as a catalogue of sort
# note that bibliographical references for FLOW in general are in the tt2 rather than here
	# data from FLOW in general, non-taxon specific
		my %rank_order_help = (); #format: en(glish name) => ordre (in the ranks hierarchy)
			# these are used to compare to the main taxon's rank order, so as to know if it is, for example suprageneric or such. Used during data visualization, but also to inform some tables further down (so as not to cross-reference constatantly).
			# note that this use of rank name as ID relies on the idea that names are unique -something more complex should be devised shall some smart aleck create multiple similarly-named ranks.
		my %nb_all = (); # number of extant and fossil genera and species; used to make percentages of the targeted taxon's subtaxons relative to the total on FLOW
			#format: ([ranks.ordre] => {extant => [nb extant taxons of the rank], fossil => [nb fossil taxons of the rank]})

	# hash of data relative to the taxon and its name, with little checking of other taxa.
		my %main_taxon_data = ();
		# data from sub: taxon_base_data_hashref
		# AND (hash of) earliest_period (name, debut, fin), (hash of) latest_period (name, debut, fin)
		# AND (if supraspecific) (hash of) earliest_species_period (name, debut, fin), (hash of) latest_species_period (name, debut, fin)
			# to check for incompletudes and discrepancies with earliest_period and latest_period. Not that species data are necessarily more complete...
			
		# TO DO: find how to get the "petit train" graph for the taxon;
		
	# hashes relative to specific taxa related to the main taxon in some important fashion
		my %hash_of_higher_taxa_data = (); # a hash of taxon_data -from the sub: taxon_base_data_hashref- for all taxa parent to the main one.
		my %type_taxon_data = (); # taxon_data -from the sub: taxon_base_data_hashref- for the highest type taxon found

	# hashes of number of extant and fossil genera and species WITHIN specific taxa; used to make percentages of the targeted taxon's subtaxons relative to the total on FLOW, or to its family's
		#format: ([ranks.ordre] => {extant => [nb extant taxons of the rank], fossil => [nb fossil taxons of the rank]})
			# it should optionally include a "monotaxa" key (number of all taxa of this rank which are the direct parent of a single taxon), but I haven't found how to pull it off yet.
				# Note that monotaxicity is a lot less meaningful beyond a certain rank, as the taxons are then MEANT to be terminal.
		my %nb_children = ();
			# Combined with %rank_order_help, allows to find number of children by named rank
		my %nb_in_family = (); #to get proportion of children compared to the family's children. Not used yet, but could.
	
	# data about the main taxon either directly taken from its data on FLOW AND/OR deduced from checking its children taxa, depending on which is available
		# focusing on species makes things comparable, but it may be interesting, at some point, to check if the taxa above or under species don't contain diverging data
		my @plants_orders =  ();
		my @wallace = (); # known as "regions_biogeo" in FLOW	
		my @holt = (); # specifically, holt regions, at least in this version
		my @tdwg = ();
	
	# hashes related to the making of graphs
		my %nb_of_sp_by_year = ();
		# format for the hashes containing final graph data:
			# my %graph_data =(
				# x_axis_graduations => [],
					# these labels will appear regularly spaced in the listed order along the x axis, centered. Consider using empty values to add spacing as needed.
				# y_axis_graduations => [],
					# these labels will appear regularly spaced in the listed order along the y axis, with the first value at the graph's base and the last at the top (thus at least two values are necessary!).
				# bars_data =>
					# [{label => "", value => , height => }],
						# when hovering over the bar, "label" and "value" appear to describe the bar x and y values respectively. Value is usually equal to height.
				# record_height => ,
			# );
		# The tt2 will add two values at the last moment: x_label and y_label, to label the axis.
	
		my %taxonomic_graph1_data =();
		my %taxonomic_graph2_data =();
		
		my %long_graph_data =();
		my %lat_graph_data =();


my @current_date = (); # needed to display the date of the text's generation
	my @current_time = localtime(time); # localtime(time) contains ($sec,$min,$hour,$month_day,$month,$year,$week_day,$year_day,$is_daylight_saving_time), with months numbered from 0 to 11 and years counted from 1900. Hence the need for some adjustments to be used.
	$current_date[0] = $current_time[3];
	$current_date[1] = $current_time[4] +1;
	$current_date[2] = $current_time[5] +1900;


my $dbc = crude_connection();

	# filling %rank_order_help
		my $req = "SELECT ordre, en FROM rangs;"; # I'll reuse the variables related to pulling data from the db, so "my" only used once for most.
		my $key_field = "en";
		my $query_result_ref = request_hash($req,$dbc,$key_field);
		my %query_result = %$query_result_ref;
		
			foreach my $key (keys %query_result)
				{$rank_order_help{$key} = $query_result{$key}{ordre};}
			
	# filling %nb_all
		%nb_all = %{census_hashref("all", $dbc)};
				
				
	# beginning to fill %main_taxon_data
		%main_taxon_data = %{taxon_base_data_hashref($id_main_taxon,$dbc)};

	# attempting to get hash about earliest and latest period in %main_taxon_data -and its constituent species if any
		# I say "attempting", because this data is rarely present in FLOW's taxons_x_periods table!
		# we'll also use noms' "fossil" value -if a taxon isn't fossil, then its latest period is necessarily extent, and its earliest MAY be too, if no other data emerges.
		# lastly, we may use the data from earliest and latest child-species to complete the taxon's data rather than to compare with them
		
		if ($main_taxon_data{is_fossil} =~ "false") # ie, if the main taxon is still (at least partially) extant
			{
			# first, get the "Extant" period's values
			$req = "SELECT en AS name, debut, fin
					FROM periodes
					WHERE en = 'Extant'";
			$key_field = "name";
			$query_result_ref = request_hash($req,$dbc,$key_field);
			%query_result = %$query_result_ref;
			
			my $extant_hash = $query_result{'Extant'};
			
			# as the main taxon is extant, its latest period is "Extant"
			$main_taxon_data{latest_period} = $extant_hash;
			
			$req = "SELECT en AS name, debut, fin
					FROM periodes
						RIGHT JOIN taxons_x_periodes ON ref_periode = periodes.index
					WHERE ref_taxon = $id_main_taxon
					ORDER BY debut DESC, niveau DESC";
			my $dim = 3;
			$query_result_ref = request_tab($req,$dbc,$dim);
			my @query_result = @$query_result_ref;
			
			if (exists $query_result[0])
				{
				$main_taxon_data{earliest_period}{name} = $query_result[0][0];
				$main_taxon_data{earliest_period}{debut} = $query_result[0][1];
				$main_taxon_data{earliest_period}{fin} = $query_result[0][2];
				}
			else # if we don't have specific data on the beginning of this still extant taxon, we at least know it was here for the extant period!
				{$main_taxon_data{earliest_period} = $extant_hash}
				
			}
		else # if the main taxon has no extant members, we do have to check the data and hope they are there
			{
			$req = "SELECT en AS name, debut, fin
					FROM periodes
						RIGHT JOIN taxons_x_periodes ON ref_periode = periodes.index
					WHERE ref_taxon = $id_main_taxon
					ORDER BY fin ASC, niveau DESC";
			my $dim = 3;
			$query_result_ref = request_tab($req,$dbc,$dim);
			my @query_result = @$query_result_ref;
			
			if (exists $query_result[0])
				{
				$main_taxon_data{latest_period}{name} = $query_result[0][0];
				$main_taxon_data{latest_period}{debut} = $query_result[0][1];
				$main_taxon_data{latest_period}{fin} = $query_result[0][2];
				}
			
			$req = "SELECT en AS name, debut, fin
					FROM periodes
						RIGHT JOIN taxons_x_periodes ON ref_periode = periodes.index
					WHERE ref_taxon = $id_main_taxon
					ORDER BY debut DESC, niveau DESC";
			$dim = 3;
			$query_result_ref = request_tab($req,$dbc,$dim);
			@query_result = @$query_result_ref;
			
			if (exists $query_result[0])
				{
				$main_taxon_data{earliest_period}{name} = $query_result[0][0];
				$main_taxon_data{earliest_period}{debut} = $query_result[0][1];
				$main_taxon_data{earliest_period}{fin} = $query_result[0][2];
				}
			}
		
		# if the main taxon is supraspecific, its species' data may contain relevant temporal information
			# we don't use them enough for me to consider worthwhile checking whether species with undefined periods are actually extant (with the period this implies)...
			if ($main_taxon_data{rank_order} < $rank_order_help{species})
				{
				$req = "SELECT periodes.en, debut, fin
						FROM taxons
							LEFT JOIN hierarchie AS h ON h.index_taxon_fils = taxons.index
							LEFT JOIN rangs ON rangs.index = taxons.ref_rang
							LEFT JOIN taxons_x_noms AS txn ON txn.ref_taxon = taxons.index
							LEFT JOIN taxons_x_periodes AS txp ON txp.ref_taxon = taxons.index
							LEFT JOIN periodes ON periodes.index = txp.ref_periode
						WHERE h.index_taxon_parent = $id_main_taxon
							AND rangs.en = 'species'
							AND ref_statut = 1
							AND periodes.en IS NOT NULL
						ORDER BY fin ASC, niveau DESC";
				my $dim = 3;
				$query_result_ref = request_tab($req,$dbc,$dim);
				my @query_result = @$query_result_ref;
				
				if (exists $query_result[0])
					{
					$main_taxon_data{latest_species_period}{name} = $query_result[0][0];
					$main_taxon_data{latest_species_period}{debut} = $query_result[0][1];
					$main_taxon_data{latest_species_period}{fin} = $query_result[0][2];
					
					if (!exists $main_taxon_data{latest_period}{name}) # if the main data has no information about its latest period, use its species'
						{
						$main_taxon_data{latest_period}{name} = $main_taxon_data{latest_species_period}{name};
						$main_taxon_data{latest_period}{debut} = $main_taxon_data{latest_species_period}{debut};
						$main_taxon_data{latest_period}{fin} = $main_taxon_data{latest_species_period}{fin};
						}
					}
					
					
				$req = "SELECT periodes.en, debut, fin
						FROM taxons
							LEFT JOIN hierarchie AS h ON h.index_taxon_fils = taxons.index
							LEFT JOIN rangs ON rangs.index = taxons.ref_rang
							LEFT JOIN taxons_x_noms AS txn ON txn.ref_taxon = taxons.index
							LEFT JOIN taxons_x_periodes AS txp ON txp.ref_taxon = taxons.index
							LEFT JOIN periodes ON periodes.index = txp.ref_periode
						WHERE h.index_taxon_parent = $id_main_taxon
							AND rangs.en = 'species'
							AND ref_statut = 1
							AND periodes.en IS NOT NULL
						ORDER BY debut DESC, niveau DESC";
				$dim = 3;
				$query_result_ref = request_tab($req,$dbc,$dim);
				@query_result = @$query_result_ref;
				
				if (exists $query_result[0])
					{
					$main_taxon_data{earliest_species_period}{name} = $query_result[0][0];
					$main_taxon_data{earliest_species_period}{debut} = $query_result[0][1];
					$main_taxon_data{earliest_species_period}{fin} = $query_result[0][2];
					
					if (!exists $main_taxon_data{earliest_period}{name}) # if the main data has no information about its earliest period, use its species'
						{
						$main_taxon_data{earliest_period}{name} = $main_taxon_data{earliest_species_period}{name};
						$main_taxon_data{earliest_period}{debut} = $main_taxon_data{earliest_species_period}{debut};
						$main_taxon_data{earliest_period}{fin} = $main_taxon_data{earliest_species_period}{fin};
						}
					}
				}


	# filling %hash_of_higher_taxa_data
	# to do this, first we seek the id of all parent taxa, then we call taxon_base_data_hashref on each to make the final hash
	# this is more queries, but ensure that if we ever alter the standard way of describing taxa in taxon_base_data_hashref, this will update
		
		$req = "SELECT ordre AS rank_order, taxons.index AS taxon_id
				FROM taxons
					LEFT JOIN rangs ON rangs.index = ref_rang
				WHERE taxons.index IN
					(SELECT index_taxon_parent FROM hierarchie
					WHERE index_taxon_fils = $id_main_taxon)";
		my $dim = 14;
		$query_result_ref = request_tab($req,$dbc,$dim);
		my @query_result = @$query_result_ref;
		
			foreach my $key (keys @query_result)
			{$hash_of_higher_taxa_data{$query_result[$key][0]} = taxon_base_data_hashref($query_result[$key][1],$dbc);}
			
			
	# filling %type_taxon_data
	# to avoid pulling a type genus and a type species, I'll first check the rank of the main taxon is above, under or between genus and species (using %rank_order_help for reference) to determine the rank of its type (if any).
	# I'll then query type taxa of the required rank -hopefully finding only one!- and then call taxon_base_data_hashref on it
	
		if ($main_taxon_data{'rank_order'} < $rank_order_help{'species'}) #remember: higher rank orders are lower in the hierarchie, and vice-versa
			{
			my $type_rank_line = "";
			if ($main_taxon_data{'rank_order'} >= $rank_order_help{'genus'})
				{$type_rank_line = "AND ordre = $rank_order_help{'species'}";}
			else {$type_rank_line = "AND ordre = $rank_order_help{'genus'}";}
			
			$req = "SELECT DISTINCT taxons.index AS type_taxon_id, ordre
				FROM taxons
					LEFT JOIN rangs ON rangs.index = ref_rang
					LEFT JOIN hierarchie ON index_taxon_fils = taxons.index
					LEFT JOIN taxons_x_noms AS txn ON txn.ref_taxon = taxons.index
					LEFT JOIN noms ON noms.index = txn.ref_nom
				WHERE
					taxons.index IN
						(SELECT index_taxon_fils FROM hierarchie
						WHERE index_taxon_parent = $id_main_taxon)
					AND gen_type IS TRUE
					$type_rank_line";
			$dim = 1;
			$query_result_ref = request_tab($req,$dbc,$dim);
			@query_result = @$query_result_ref;
			
				foreach my $key (keys @query_result)
				{%type_taxon_data = %{taxon_base_data_hashref($query_result[$key], $dbc)};}
			}
	
		
	# filling %nb_children
		%nb_children = %{census_hashref($id_main_taxon, $dbc)};
		
	# filling %nb_in_family, if defined
	# involves using %rank_order_help to check %hash_of_higher_taxa_data for the family's taxon id, then call census_hashref on it
		if (exists $hash_of_higher_taxa_data{$rank_order_help{family}})
			{%nb_in_family = %{census_hashref($hash_of_higher_taxa_data{$rank_order_help{family}}{id}, $dbc)};}
	

	# filling @plants_orders
	# involves checking the main taxon and its son species, if there are any
	# these plant orders are spread between plantes and taxons_associes. To avoid duplications between tables, I'll temporarily store the orders as keys from a hash, so repetitions are simply crushed.
	# note the use of get_taxon_associe_rg_sup and get_parent_host_plant; these functions are implemented in the databse itself
		my %temp_orders;
		$req = "SELECT DISTINCT get_taxon_associe_rg_sup
					(ta.index, (SELECT rangs.index FROM rangs WHERE rangs.en = 'order'))
					AS order
				FROM taxons_associes AS ta
					LEFT JOIN taxons_x_taxons_associes AS txta ON txta.ref_taxon_associe = ta.index
					LEFT JOIN types_association AS typa ON typa.index = txta.ref_type_association
					LEFT JOIN taxons ON taxons.index = txta.ref_taxon
					LEFT JOIN taxons_x_noms AS txn ON txn.ref_taxon = taxons.index
					LEFT JOIN hierarchie AS h ON h.index_taxon_fils = taxons.index
					LEFT JOIN rangs ON rangs.index = taxons.ref_rang
				WHERE
					((h.index_taxon_parent = $id_main_taxon AND rangs.en = 'species') OR taxons.index = $id_main_taxon)
					AND ref_statut = 1
					AND statut = 'valid'
					AND typa.en IN ('Host-plant','food plant')";
		$key_field = "order";
		$query_result_ref = request_hash($req,$dbc,$key_field);
		%query_result = %$query_result_ref;
		
			foreach my $key (keys %query_result)
				{$temp_orders{$key} = "y";} #the value is unimportant since we only use a hash for the unicity of the keys
				
		$req = "SELECT DISTINCT plantes_orders.nom AS order
				FROM plantes
					LEFT JOIN taxons_x_plantes AS txp ON txp.ref_plante = plantes.index
					LEFT JOIN taxons ON taxons.index = txp.ref_taxon
					LEFT JOIN taxons_x_noms AS txn ON txn.ref_taxon = taxons.index
					LEFT JOIN hierarchie AS h ON h.index_taxon_fils = taxons.index
					LEFT JOIN rangs ON rangs.index = taxons.ref_rang
					LEFT JOIN plantes AS plantes_orders ON plantes_orders.index = get_parent_host_plant(plantes.index,'order')
				WHERE
					((h.index_taxon_parent = $id_main_taxon AND rangs.en = 'species') OR taxons.index = $id_main_taxon)
					AND ref_statut = 1
					AND plantes_orders.nom IS NOT NULL"; #it may be wise to add a similar precaution in other queries, just in case
		$key_field = "order";
		$query_result_ref = request_hash($req,$dbc,$key_field);
		%query_result = %$query_result_ref;
		
			foreach my $key (keys %query_result)
				{$temp_orders{$key} = "y"}
				
		@plants_orders = keys %temp_orders;
	
	
	# beginning to fill @wallace, using taxons_x_regions_biogeo
	# the array can also be filled through accessing the regions corresponding to pays from taxons_x_pays; to ensure exhaustivity, I'll check both paths.
		# to avoid duplicated date, (as for @plants_orders), I'll store the list elements as keys in a temporary hash.
		
	my %temp_wal;
		
		$req = "SELECT DISTINCT
					bioreg.en AS wal
				FROM taxons
					LEFT JOIN hierarchie AS h ON h.index_taxon_fils = taxons.index
					LEFT JOIN rangs ON rangs.index = taxons.ref_rang
					LEFT JOIN taxons_x_noms AS txn ON txn.ref_taxon = taxons.index
					LEFT JOIN taxons_x_regions_biogeo AS txw ON txw.ref_taxon = taxons.index
					RIGHT JOIN regions_biogeo AS bioreg ON bioreg.index = txw.ref_region_biogeo
				WHERE ((h.index_taxon_parent = $id_main_taxon AND rangs.en = 'species') OR taxons.index = $id_main_taxon)
					AND ref_statut = 1";
		$key_field = "wal";
		$query_result_ref = request_hash($req,$dbc,$key_field);
		%query_result = %$query_result_ref;
		
			foreach my $key (keys %query_result)
				{$temp_wal{$key} = "y";} #the value is unimportant since we only use a hash for the unicity of the keys
		
	# filling data variables related to pays: finishing filling @wallace through pays, holt, tdwg, geographical graph datas
		# consideration: we may someday treat differently zones where the taxa are native and alien
	# to avoid duplicated date, (as for @plants_orders), I'll store the list elements as keys in temporary hashes.
	
		# so as to make the graphs, I want ordered lists of midl_long and midl_lat, to count the occurrences of species in longitude and latitude spans;
			# to make a single request, I order the query result by long, constitute a list of lat in the for loop, and then order the lat list.
	
		# we want tdwg  areas of rank 2 for suprageneric taxons, but 3 or 4 for generic (and subgeneric?) taxons; beside we already know it's largely futile to check the children of species and subspecific taxons.
		# I'll thus test the main taxon's rank to make slightly different requests.
		my %temp_holt; my %temp_tdwg;
		my @midl_longs; my @midl_lats;
		
		if ($main_taxon_data{'rank_order'} < $rank_order_help{'genus'}) #remember: higher rank orders are lower in the hierarchie, and vice-versa
			{$req = "SELECT
						bioreg.en AS wal,
						holt_regions.en AS holt_region,
						get_tdwg_parent_by_level(tdwg, 2) AS tdwg,
						round(midl_long, 0) as midl_long, round(midl_lat,0) AS midl_lat
					FROM taxons
						LEFT JOIN hierarchie AS h ON h.index_taxon_fils = taxons.index
						LEFT JOIN rangs ON rangs.index = taxons.ref_rang
						LEFT JOIN taxons_x_noms AS txn ON txn.ref_taxon = taxons.index
						LEFT JOIN taxons_x_pays AS txp ON txp.ref_taxon = taxons.index
						LEFT JOIN pays ON pays.index = txp.ref_pays
						LEFT JOIN taxons_x_regions_biogeo AS txw ON txw.ref_taxon = taxons.index
						LEFT JOIN regions_biogeo AS bioreg ON bioreg.index = pays.ref_biogeo
						LEFT JOIN holt_regions ON holt_regions.index = pays.ref_holt
					WHERE h.index_taxon_parent = $id_main_taxon
						AND rangs.en = 'species'
						AND ref_statut = 1
					ORDER by midl_long ASC";}
		elsif ($main_taxon_data{'rank_order'} < $rank_order_help{'species'})
			{$req = "SELECT
						bioreg.en AS wal,
						holt_regions.en AS holt_region,
						tdwg,
						round(midl_long, 0) as midl_long, round(midl_lat,0) AS midl_lat
					FROM taxons
						LEFT JOIN hierarchie AS h ON h.index_taxon_fils = taxons.index
						LEFT JOIN rangs ON rangs.index = taxons.ref_rang
						LEFT JOIN taxons_x_noms AS txn ON txn.ref_taxon = taxons.index
						LEFT JOIN taxons_x_pays AS txp ON txp.ref_taxon = taxons.index
						LEFT JOIN pays ON pays.index = txp.ref_pays
						LEFT JOIN taxons_x_regions_biogeo AS txw ON txw.ref_taxon = taxons.index
						LEFT JOIN regions_biogeo AS bioreg ON bioreg.index = pays.ref_biogeo
						LEFT JOIN holt_regions ON holt_regions.index = pays.ref_holt
					WHERE h.index_taxon_parent = $id_main_taxon
						AND rangs.en = 'species'
						AND ref_statut = 1
					ORDER by midl_long ASC";}
		else {$req = "SELECT
						bioreg.en AS wal,
						holt_regions.en AS holt_region,
						tdwg,
						round(midl_long, 0) as midl_long, round(midl_lat,0) AS midl_lat
					FROM taxons
						LEFT JOIN taxons_x_noms AS txn ON txn.ref_taxon = taxons.index
						LEFT JOIN taxons_x_pays AS txp ON txp.ref_taxon = taxons.index
						LEFT JOIN pays ON pays.index = txp.ref_pays
						LEFT JOIN taxons_x_regions_biogeo AS txw ON txw.ref_taxon = taxons.index
						LEFT JOIN regions_biogeo AS bioreg ON bioreg.index = pays.ref_biogeo
						LEFT JOIN holt_regions ON holt_regions.index = pays.ref_holt
					WHERE taxons.index = $id_main_taxon
						AND ref_statut = 1
					ORDER by midl_long ASC";}
			
		$dim = 30; # /!\ I don't know what dimension is best here.
		$query_result_ref = request_tab($req,$dbc,$dim);
		@query_result = @$query_result_ref;
			
			foreach my $key (keys @query_result)
				# hard-won experience shows not all "pays" rows have wallacean region, holt, tdwg or even latitude and longitude filled (check for Russia for example).
				# this makes checking if the value exists necessary before putting it as key into a hash.
				{if (defined $query_result[$key][0])
					{$temp_wal{$query_result[$key][0]} = "y"} #the value is unimportant since we only use a hash for the unicity of the keys
				if (defined $query_result[$key][1])
					{$temp_holt{$query_result[$key][1]} = "y"}
				if (defined $query_result[$key][2])
					{$temp_tdwg{$query_result[$key][2]} = "y"}
				push(@midl_longs, $query_result[$key][3]); # pre-ordered by the query, so won't have to be sorted later
				push(@midl_lats, $query_result[$key][4]);}
				
		@wallace = grep defined, keys %temp_wal;
		@holt = grep defined, keys %temp_holt;
		@tdwg = grep defined, keys %temp_tdwg;
		@midl_longs = grep defined, @midl_longs;
		@midl_lats = sort {$a <=> $b} grep defined, @midl_lats;
				
				
	# filling %long_graph_data using @midl_longs		
		$long_graph_data{record_height} = 0;
		my $current_midl_long = 0;
		for (my $bar_western_longitude = -180; $bar_western_longitude < 180; $bar_western_longitude = $bar_western_longitude + 5)
			# each bar covers a 5 degree span, named for its westernest longitude
			# for each, check if the current element from @midl_longs is in it
				# if yes, is counted and we move on to the next element, if no, we update %long_graph_data (bar_data and record_height) and move on to the next span.
			{
			my $sp_in_span = 0;
			
			if (defined $midl_longs[$current_midl_long]) # no point checking beyond @midl_longs' last element, but we still need to fill the graph's end with empty value and so can't outright break.
				{
				while ($bar_western_longitude <=  $midl_longs[$current_midl_long] < $bar_western_longitude + 5)
					{
					$sp_in_span = $sp_in_span + 1;
					$current_midl_long = $current_midl_long + 1;
					if (!defined $midl_longs[$current_midl_long])
						{last} # needed because $current_midl_long is modified before the while's check for the next loop. I'd like it to be implemented in the while check itself, but couldn't do it.
					}
				}
			
			$long_graph_data{record_height} = (sort {$a <=> $b} ($long_graph_data{record_height}, $sp_in_span))[-1];
			
			my $bar_eastern_longitude = $bar_western_longitude + 5;
			push(@{$long_graph_data{bars_data}}, {value => $sp_in_span, height => $sp_in_span, label => "$bar_western_longitude to $bar_eastern_longitude\°"});
			
			}
			
		# in the x axis labels, the 360° of longitudes are divided into equal spans labelled after their middle longitude
			my $nb_div = 9; # used as variable to be easily changed if needed. 360%$nb_div doit être nul.
			my $x_grad_span = 360/$nb_div;
			for (my $x_grad_western_longitude = -180; $x_grad_western_longitude < 180; $x_grad_western_longitude = $x_grad_western_longitude + $x_grad_span)
				{
				my $x_grad_midl = $x_grad_western_longitude + $x_grad_span/2;
				push(@{$long_graph_data{x_axis_graduations}}, "$x_grad_midl\°");
				}
				
		# using the record height as reference, making the graduations for the y axis.
			# for spacing reasons, all heights will have a value; for lisibility reason, only a few of them will have a non-null value to display
				# I arbitrarily chose to aim for 2 y-axis graduations at least and 6 at most for aesthetic reasons, but you may wish to change that.
		if ($long_graph_data{record_height} < 5)
			{foreach my $ygrad (0..$long_graph_data{record_height})
				{push(@{$long_graph_data{y_axis_graduations}}, $ygrad);}
			}
		else
			{foreach my $ygrad (0..$long_graph_data{record_height})
				{
				if ($ygrad == 0 or $ygrad%(int($long_graph_data{record_height}/5)) == 0)
					{push(@{$long_graph_data{y_axis_graduations}}, $ygrad);}
				else
					{push(@{$long_graph_data{y_axis_graduations}}, "");}
				}
			}
			
			
	# filling %lat_graph_data using @midl_lats
		$lat_graph_data{record_height} = 0;
		my $current_midl_lat = 0;
		for (my $bar_northern_latitude = -90; $bar_northern_latitude < 90; $bar_northern_latitude = $bar_northern_latitude + 5)
			# each bar covers a 5 degree span, named for its northernest latitude
			# for each, check if the current element from @midl_lats is in it
				# if yes, is counted and we move on to the next element, if no, we update %lat_graph_data (bar_data and record_height) and move on to the next span.
			{
			my $sp_in_span = 0;
			
			if (defined $midl_lats[$current_midl_lat]) # no point checking beyond @midl_lats' last element, but we still need to fill the graph's end with empty value and so can't outright break.
				{
				while ($bar_northern_latitude <=  $midl_lats[$current_midl_lat] < $bar_northern_latitude + 5)
					{
					$sp_in_span = $sp_in_span + 1;
					$current_midl_lat = $current_midl_lat + 1;
					if (!defined $midl_lats[$current_midl_lat])
						{last} # needed because $current_midl_lat is modified before the while's check for the next loop. I'd like it to be implemented in the while check itself, but couldn't do it.
					}
				}
			
			$lat_graph_data{record_height} = (sort {$a <=> $b} ($lat_graph_data{record_height}, $sp_in_span))[-1];
			
			my $bar_southern_latitude = $bar_northern_latitude + 5;
			push(@{$lat_graph_data{bars_data}}, {value => $sp_in_span, height => $sp_in_span, label => "$bar_northern_latitude to $bar_southern_latitude\°"});
			
			}
			
		# in the x axis labels, the 180° of latitudes are divided into equal spans labelled after their middle latitude
			$nb_div = 9; # used as variable to be easily changed if needed. 180%$nb_div doit être nul.
			$x_grad_span = 180/$nb_div;
			for (my $x_grad_northern_latitude = -90; $x_grad_northern_latitude < 90; $x_grad_northern_latitude = $x_grad_northern_latitude + $x_grad_span)
				{
				my $x_grad_midl = $x_grad_northern_latitude + $x_grad_span/2;
				push(@{$lat_graph_data{x_axis_graduations}}, "$x_grad_midl\°");
				}
				
		# using the record height as reference, making the graduations for the y axis.
			# for spacing reasons, all heights will have a value; for lisibility reason, only a few of them will have a non-null value to display
				# I arbitrarily chose to aim for 2 y-axis graduations at least and 6 at most for aesthetic reasons, but you may wish to change that.
		if ($lat_graph_data{record_height} < 5)
			{foreach my $ygrad (0..$lat_graph_data{record_height})
				{push(@{$lat_graph_data{y_axis_graduations}}, $ygrad);}
			}
		else
			{foreach my $ygrad (0..$lat_graph_data{record_height})
				{
				if ($ygrad == 0 or $ygrad%(int($lat_graph_data{record_height}/5)) == 0)
					{push(@{$lat_graph_data{y_axis_graduations}}, $ygrad);}
				else
					{push(@{$lat_graph_data{y_axis_graduations}}, "");}
				}
			}

	
	# IF the main taxon is suprageneric, filling the taxonomic graphs				
		if ($main_taxon_data{'rank_order'} < $rank_order_help{'species'}) #remember: higher rank orders are lower in the hierarchie, and vice-versa
			{
			$req = "SELECT
						distinct annee AS date,
						(SELECT count(distinct taxons.index) AS punctual
							FROM taxons
								LEFT JOIN hierarchie AS h ON h.index_taxon_fils = taxons.index
								LEFT JOIN rangs ON rangs.index = taxons.ref_rang
								LEFT JOIN taxons_x_noms AS txn ON txn.ref_taxon = taxons.index
								LEFT JOIN noms AS noms2 ON noms2.index = txn.ref_nom
							WHERE h.index_taxon_parent = $id_main_taxon
								AND rangs.en = 'species'
								AND ref_statut = 1
								AND noms2.annee = noms.annee),
						(SELECT count(distinct taxons.index) AS cumulative
							FROM taxons
								LEFT JOIN hierarchie AS h ON h.index_taxon_fils = taxons.index
								LEFT JOIN rangs ON rangs.index = taxons.ref_rang
								LEFT JOIN taxons_x_noms AS txn ON txn.ref_taxon = taxons.index
								LEFT JOIN noms AS noms3 ON noms3.index = txn.ref_nom
							WHERE h.index_taxon_parent = $id_main_taxon
								AND rangs.en = 'species'
								AND ref_statut = 1
								AND noms3.annee <= noms.annee)
					FROM taxons
						LEFT JOIN hierarchie AS h ON h.index_taxon_fils = taxons.index
						LEFT JOIN rangs ON rangs.index = taxons.ref_rang
						LEFT JOIN taxons_x_noms AS txn ON txn.ref_taxon = taxons.index
						LEFT JOIN noms ON noms.index = txn.ref_nom
					WHERE h.index_taxon_parent = $id_main_taxon
						AND rangs.en = 'species'
						AND ref_statut = 1
					ORDER BY date ASC";
			$key_field = "date";
			$query_result_ref = request_hash($req,$dbc,$key_field);
			%query_result = %$query_result_ref;
				
				my ($first_year, $last_year) = (sort {$a <=> $b} (keys %query_result))[0,-1]; # there has to be a module to write this more elegantly
				$taxonomic_graph1_data{record_height} = 0;$taxonomic_graph2_data{record_height} = $query_result{$last_year}{cumulative};
				foreach my $year ($first_year..$current_date[2]) # consider choosing alternate dates of beginning and end
					{
					# adding this year's bar data to both taxonomic graphs, updating $taxonomic_graph1_data{record_height}
					if (exists $query_result{$year})
						{
						push(@{$taxonomic_graph1_data{bars_data}}, {value => $query_result{$year}{punctual}, height => $query_result{$year}{punctual}, label => $year});
						push(@{$taxonomic_graph2_data{bars_data}}, {value => $query_result{$year}{cumulative}, height => $query_result{$year}{cumulative}, label => $year});
							
						$taxonomic_graph1_data{record_height} = (sort {$a <=> $b} ($taxonomic_graph1_data{record_height},$query_result{$year}{punctual}))[-1]
						}
					else
						{
						push(@{$taxonomic_graph1_data{bars_data}}, {value => 0, height => 0, label => $year});
						my $tg2_previous_year_value = $taxonomic_graph2_data{bars_data}[-1]{value};
							# Note that this previous line relies on a previous value existing;
							# it will require heavy modifications should the graph begins before the first species description.
						push(@{$taxonomic_graph2_data{bars_data}}, {value => $tg2_previous_year_value, height => $tg2_previous_year_value, label => $year}); # by default, the cumulative number of species stay the same.
						}
						
					# adding the x-axis graduations to both graphs
					# for spacing reasons, all years will have a value; for lisibility reason, only a few of them -say, those divisible by 20- will have a non-null value to display
					if ($year%20 == 0)
						{push(@{$taxonomic_graph1_data{x_axis_graduations}}, $year);
						push(@{$taxonomic_graph2_data{x_axis_graduations}}, $year);}
					else
						{push(@{$taxonomic_graph1_data{x_axis_graduations}}, "");
						push(@{$taxonomic_graph2_data{x_axis_graduations}}, "");}
					}
			
			# using the record height as reference, making the graduations for the y axis.
			# for spacing reasons, all heights will have a value; for lisibility reason, only a few of them will have a non-null value to display
				# I arbitrarily chose to aim for 2 y-axis graduations at least and 6 at most for aesthetic reasons, but you may wish to change that.
				if ($taxonomic_graph1_data{record_height} < 5)
					{foreach my $ygrad (0..$taxonomic_graph1_data{record_height})
						{push(@{$taxonomic_graph1_data{y_axis_graduations}}, $ygrad);}
					}
				else
					{foreach my $ygrad (0..$taxonomic_graph1_data{record_height})
						{
						if ($ygrad == 0 or $ygrad%(int($taxonomic_graph1_data{record_height}/5)) == 0)
							{push(@{$taxonomic_graph1_data{y_axis_graduations}}, $ygrad);}
						else
							{push(@{$taxonomic_graph1_data{y_axis_graduations}}, "");}
						}
					}
				

				if ($taxonomic_graph2_data{record_height} < 5)
					{foreach my $ygrad (0..$taxonomic_graph2_data{record_height})
						{push(@{$taxonomic_graph2_data{y_axis_graduations}}, $ygrad);}
					}
				else
					{foreach my $ygrad (0..$taxonomic_graph2_data{record_height})
						{
						if ($ygrad == 0 or $ygrad%(int($taxonomic_graph2_data{record_height}/5)) == 0)
							{push(@{$taxonomic_graph2_data{y_axis_graduations}}, $ygrad);}
						else
							{push(@{$taxonomic_graph2_data{y_axis_graduations}}, "");}
						}
					}
			}
		

$dbc->disconnect;

# with a taxon id or "all" and database connection (which needs to be done beforehand) as input, grab count of children taxa within the taxon (or FLOW for "all"), divided between fossil and extent, from the db.
	# returns a hashref: ([ranks.ordre] => {extant => [nb extant taxons of the rank], fossil => [nb fossil taxons of the rank]})
sub census_hashref {
	my ($taxon_id, $dbc) = @_;
	
	my %census_hash;
	
	my $research_restraint = "";
	if ($taxon_id !~ "all")
		{$research_restraint = "AND index_taxon_parent = $taxon_id";}
	
	# /!\ WARNING: as of now, I am still unsure about this query, and which taxons should be included in the census.
		# should the line "[WHERE] ref_statut = 1 AND completude IS NOT false AND exactitude IS NOT false" be included?
	$req = "SELECT rank_order, is_fos,
				count(subquery.subtaxa),
				count(CASE WHEN nb_children = 1 THEN 1 END) AS monotaxa
			FROM
				(SELECT taxons.index AS subtaxa, ordre AS rank_order, noms.fossil AS is_fos,
					(SELECT count(DISTINCT subtaxons.index) AS nb_children
							FROM taxons AS subtaxons
							LEFT JOIN hierarchie AS subh ON subh.index_taxon_fils = subtaxons.index
							LEFT JOIN taxons_x_noms AS txn2 ON txn2.ref_taxon = subtaxons.index
						   WHERE txn2.ref_statut = 1
								AND subh.index_taxon_parent = hierarchie.index_taxon_fils)
				FROM taxons
					LEFT JOIN rangs AS r ON r.index = ref_rang
					LEFT JOIN taxons_x_noms AS txn ON txn.ref_taxon = taxons.index
					LEFT JOIN noms ON noms.index = txn.ref_nom
					LEFT JOIN hierarchie ON hierarchie.index_taxon_fils = taxons.index
				WHERE txn.ref_statut = 1
					AND hierarchie.index_taxon_parent = $id_main_taxon
				GROUP BY taxons.index, r.ordre, is_fos, hierarchie.index_taxon_fils ORDER BY r.ordre)
				AS subquery
			GROUP BY rank_order, is_fos";
	my $dim = 4;
	$query_result_ref = request_tab($req,$dbc,$dim);
	my @query_result = @$query_result_ref;
	
		foreach my $key (keys @query_result) # /!\ WARNING: this too behaves oddly, with the "extant" (and "unclear") value somehow not corresponding exactly to the result of the query!
			{my $rankorder = $query_result[$key][0];
			my $is_fos;
				if (!defined $query_result[$key][1]) {$is_fos = "unclear"} #pretty sure "unclear" is an anomalous bug, but I'd rather have a case for it so it doesn't have knock-on effects on the rest.
				elsif ($query_result[$key][1] == 0){$is_fos = "extant"}
				elsif ($query_result[$key][1] == 1){$is_fos = "fossil"};
			$census_hash{$rankorder}{$is_fos} = $query_result[$key][2];
			if (exists $census_hash{$rankorder}{monotaxa})
				{$census_hash{$rankorder}{monotaxa} = $census_hash{$rankorder}{monotaxa} + $query_result[$key][3]} # so as to sum for the extant and the fossil row
			else {$census_hash{$rankorder}{monotaxa} = $query_result[$key][3]}
			}
	
	return \%census_hash;
	}


# with a taxon id and database connection (which needs to be done beforehand) as input, grab data from the db and return a reference to a standardized hash containing these data.
	# keys (with explanation):
		# (complete) name,
		# (list of) authors, (list of) authors_with_forename, full_authorship,
		# reference (publication title), revue, volume, fascicule, page_debut, page_fin,
		# date (of publication), rank, rank_order, is_fossil, is_type, id
		# (list of) depositories (as hashes whose keys are: depository, country)
sub taxon_base_data_hashref {
	my ($taxon_id, $dbc) = @_;
	
	my %taxon_base_data_hash;
	
	# being unsure about the proper way to make citations, I may have missed important data; consider checking it
	$req = "SELECT
				noms_complets.orthographe AS name,
				titre AS reference, revues.nom AS revue, volume, fascicule, page_debut, page_fin,
				get_ref_authors(noms_complets.ref_publication_princeps) AS full_authorship, annee AS date,
				rangs.en AS rank, rangs.ordre AS rank_order,
				noms_complets.fossil AS is_fossil, noms_complets.gen_type AS is_type,
				taxons.index AS id
			FROM public.taxons
				LEFT JOIN taxons_x_noms AS txn ON txn.ref_taxon = taxons.index
				LEFT JOIN noms_complets ON noms_complets.index = txn.ref_nom
				LEFT JOIN publications ON publications.index = noms_complets.ref_publication_princeps
				LEFT JOIN revues ON revues.index = publications.ref_revue
				LEFT JOIN rangs ON rangs.index = taxons.ref_rang
			WHERE taxons.index = $taxon_id AND ref_statut = 1
			GROUP BY taxons.index, name, reference, revues.nom, volume, fascicule, page_debut, page_fin,
				noms_complets.ref_publication_princeps, annee, rank, rank_order, is_fossil, noms_complets.gen_type";
	$key_field = "name";
	$query_result_ref = request_hash($req,$dbc,$key_field);
	%query_result = %$query_result_ref;
		
		foreach my $key (keys %query_result)
			{
			my $subarray_ref = $query_result{$key};
			foreach my $subkey (keys %$subarray_ref)
				{$taxon_base_data_hash{$subkey} = $$subarray_ref{$subkey}}
			}

	$req = "SELECT
				auteurs.index,
				auteurs. prenom, auteurs.nom
			FROM public.taxons
				LEFT JOIN taxons_x_noms AS txn ON txn.ref_taxon = taxons.index
				LEFT JOIN noms_x_auteurs AS nxa ON nxa.ref_nom = txn.ref_nom
				LEFT JOIN auteurs ON auteurs.index = nxa.ref_auteur
			WHERE taxons.index = $taxon_id AND ref_statut = 1
			ORDER BY position";
	$key_field = "index";
	$query_result_ref = request_hash($req,$dbc,$key_field);
	%query_result = %$query_result_ref;
		
		my @auteurs_noms_list; my @auteurs_fullname_list; # because there may be multiple authors, I make a separate request
		foreach my $key (keys %query_result)
			{
			my $prenom = $query_result{$key}{prenom}; my $nom = $query_result{$key}{nom};
			push(@auteurs_noms_list,$nom);push(@auteurs_fullname_list,"$nom $prenom")
			}
		$taxon_base_data_hash{'authors'} = \@auteurs_noms_list; $taxon_base_data_hash{'authors_with_forename'} = \@auteurs_fullname_list;
	
	# sure, for now this is an unnecessarily complicated way to get depositories, but I feel like we may desire more precise information on types eventually.
	$req = "SELECT
				nxt.oid AS field_key, txt.en AS type, quantite AS quantity, sexes.en AS sex, lieux_depot.nom AS depository, pays.en AS country
			FROM public.taxons
				LEFT JOIN taxons_x_noms AS txn ON txn.ref_taxon = taxons.index
				LEFT JOIN noms_x_types AS nxt ON nxt.ref_nom = txn.ref_nom
				LEFT JOIN types_type AS txt ON txt.index = nxt.ref_type
				LEFT JOIN lieux_depot ON lieux_depot.index = nxt.ref_lieux_depot
				LEFT JOIN pays ON pays.index = lieux_depot.ref_pays
				LEFT JOIN sexes ON sexes.index = nxt.ref_sexe
			WHERE taxons.index = $taxon_id AND ref_statut = 1";
	$key_field = "field_key";
	$query_result_ref = request_hash($req,$dbc,$key_field);
	%query_result = %$query_result_ref;
	
		my @types_list;
		foreach my $key (keys %query_result)
			{
			my $depository = $query_result{$key}{depository}; my $country = $query_result{$key}{country};
			my %deposit_hash = (depository => $depository, country => $country);
			push(@types_list, \%deposit_hash);
			}
		$taxon_base_data_hash{'depositories'} = \@types_list;
	
	return \%taxon_base_data_hash;
	}


# "returns a reference to a hash containing a key for each distinct value of the $key_field column that was fetched. For each key the corresponding value is a reference to a hash containing all the selected columns and their values, as returned by fetchrow_hashref()."
# copied from DBCommands.pm, consider modifying this to directly access DBCommands.pm instead
sub request_hash {
	my ($req,$dbh,$key_field) = @_; # get query
	my $hash_ref;
	if ( my $sth = $dbh->prepare($req) ){ # prepare
		if ( $sth->execute() ){ # execute
			
			unless ($hash_ref = $sth->fetchall_hashref( $key_field )) { die "Could'nt fetch all in hash: $DBI::errstr\n" }
			$sth->finish(); # finalize the request

		}
		else { die "Could'nt execute sql request: $DBI::errstr\n--$req--\n" } # Could'nt execute sql request
	} else { die "Could'nt prepare sql request: $DBI::errstr\n" } # Could'nt prepare sql request

	return $hash_ref;
}

# copied from DBCommands.pm, consider modifying this to directly access DBCommands.pm instead
sub request_tab {
	my ($req,$dbh,$dim) = @_; # get query
	my $tab_ref = [];
	if ( my $sth = $dbh->prepare($req) ){ # prepare
		if ( $sth->execute() ){ # execute
			if ($dim eq 1) {
				while ( my @row = $sth->fetchrow_array ) {
    					push(@{$tab_ref},$row[0]);
  				}
			} else {
				$tab_ref = $sth->fetchall_arrayref;
			}
			$sth->finish(); # finalize the request

		}
		else { die "Could'nt execute sql request: $DBI::errstr\n--$req--\n" } # Could'nt execute sql request
	} else { die "Could'nt prepare sql request: $DBI::errstr\n" } # Could'nt prepare sql request

	return $tab_ref;
}

sub respond { # blindly copied from Root.pm; some parts may be in excess
  my ($self, $c) = @_;

  # objet pour la réponse
  my $res = $c->req->new_response(200);
  $res->content_type('text/html; charset=UTF-8');

  # fonction de traduction 
  my $xlang         = $c->param('lang') || 'en';
  my $dbh_traduc    = $self->dbh_for('traduction_utf8');
  my $traductions   = $dbh_traduc->selectall_hashref("SELECT id, $xlang FROM traductions", "id");
  my $traduc        = sub {my $id = shift; return $traductions->{$id}{$xlang} || $id};


  # données de stash qui seront passées au template
  $c->add_into_stash(
		current_date => \@current_date,
		rank_order_help => \%rank_order_help,
		nb_all => \%nb_all,
		main_taxon_data => \%main_taxon_data,
		# name and publication data for related taxa
			hash_of_higher_taxa_data =>\%hash_of_higher_taxa_data,
			type_taxon_data => \%type_taxon_data,
		nb_children => \%nb_children,
		nb_in_family => \%nb_in_family,
		taxonomic_graph1_data => \%taxonomic_graph1_data,
		taxonomic_graph2_data => \%taxonomic_graph2_data,
		lat_graph_data => \%lat_graph_data,
		long_graph_data => \%long_graph_data,
		tdwg_array => \@tdwg,
		wallace_array => \@wallace,
		holt_array => \@holt,
		plants_orders => \@plants_orders,
		
		test => \%test,
   );


  # génération du HTML à travers le template
  my $tmpl = Template->new({INCLUDE_PATH => $self->root_dir . '/src/tmpl'}); # obviously, the path will need to be adapted if the tt2 is moved
  $tmpl->process("autotext.tt2", {c => $c, $c->stash->%*}, \my $html)
    or die $tmpl->error;

  # suppression des éventuels liens absolus vers le serveur d'origine (par ex. en DB dans la table 'images')
  $html =~ s[https?://\w+\.hemiptera-databases\.org][]g;

  # renvoi de la réponse
  $res->body(encode_utf8($html));
  return $res->finalize;
}

1;

# not sure what to put exactly in the END section
__END__

=encoding utf8

=head1 NAME

App::Flow::Controller::Autotext - "synopsis" texts generator for the FLOW database

=head1 DESCRIPTION




=head1 AUTHOR

Florian Lafosse-Marin, August 2023.

=head1 COPYRIGHT AND LICENSE

Copyright 2023 by Florian Lafosse-Marin.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
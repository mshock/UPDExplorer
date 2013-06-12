#! perl -w

# query all tables for upd rows

use strict;
use feature 'say';
use DBI;
use Config::Simple;
use Getopt::Long;

my @excludes = qw(
	update_errors
	update_status
	MQASys
	DependInfo
	DependIntermInfo
	TableInfo
	ExportInfo
	FileGroupInfo
	NullMappingInfo
	OverrideTableSchema
	ErrorInfo
	update_log
	Update_BadRecs
);

my ( $upd, $table, $view, $download ) = ('') x 4;
GetOptions( 'upd:s'    => \$upd,
			'table:s'  => \$table,
			'view:s'     => \$view,
			'download:s' => \$download
);

my ( $fd, $fn ) = $upd =~ m/^(\d+)-(\d+)$/;

my $filename = '';
my $tmp_fh;
print "HTTP/1.0 200 OK\r\n";
print "Content-type: text/html\n\n";
print "	<html>
			<head>
				<title>UPDExplorer $upd $table</title>
				<link rel='stylesheet' type='text/css' href='styles.css' />
			</head>	
			<body>
			<table class='popup' align='center'>
			<tr>
				<th><h1>UPDExplorer</h1></th>
			</tr>";

if ( !$fd || !$fn ) {
	print "
		<form method='GET'>
		<tr>
			<th>
			<label for='upd'>UPD</label> <br>
			</th>
		</tr>
		<tr>
			<td>
			<input type='text' name='upd' id='upd'/> <br>
			</td>
		</tr>
		<tr>
			<th>
			<label for='table'>Table (optional)</label> <br>
			</th>
		</tr>
		<tr>
			<td>
			<input type='text' name='table' id='table'/> <br>
			</td>
		</tr>
		<tr>
			<td>
			
			<input type='radio' id='view' name='view' value='true' checked/>

			<label for='view'>View</label>
			</td>
		</tr>
		<tr> 
			<td>
			<input type='radio' id='download' name='download' value='true' />
			<label for='download'>Download</label> <br>
			</td>
		</tr>
		<tr>
			<td>
			<input type='submit' value='go' />
			</td>
		</tr>
		</form>
	";
}

else {
	my $cfg = new Config::Simple('dbs.conf');

	my $cdb = $cfg->param( -block => 'CDB' );

	my ($cdb_dbh) = map { init_handle($_) } ($cdb);
	my @selected_table = ( [$table] );
	my $tnames_aref
		= $table
		? \@selected_table
		: $cdb_dbh->selectall_arrayref('select name from sys.tables');


	if ($download) {
		$filename = $table ? "${upd}_$table.UPD" : "$upd.UPD";
		open( UPD, ">Files/$filename" );
	}
	else {
		open ($tmp_fh, '+>', undef) or die "could not open temp file: $!"; 
	}

	for my $tname_aref (@$tnames_aref) {
		my $tname        = $tname_aref->[0];
		my $exclude_flag = 0;
		for (@excludes) {
			if (m/$tname/) {
				$exclude_flag = 1;
				last;
			}
		}
		next if $exclude_flag;

		my $select_upd_query = "
			select * from $tname
			where 
			FileDate_ = $fd
			and FileNum_ = $fn
			order by RowNum_ asc
		";
		my $upd_rows_aref = $cdb_dbh->selectall_arrayref($select_upd_query) or die $select_upd_query;

		if ( length @$upd_rows_aref > 1 ) {
			if ($view) {
				print $tmp_fh "<tr><th>[$tname]</th></tr>";
			}
			elsif ($download) {
				say UPD "[$tname]"; 
			}
		}
		else {
			next;
		}

		for my $upd_row_aref (@$upd_rows_aref) {
			my @output_row;
			my ( $filedate, $filenum, $rownum, @upd_row ) = @$upd_row_aref;
			for my $val (@upd_row) {
				$val = defined $val ? $val : '';
				$val =~ s/[^[:ascii:]]+//g;
				push @output_row, "<td>$val</td>";

			}

			if ($view) {
				print $tmp_fh '<tr>', join( '', @output_row ), '</tr>';
			}
			elsif ($download) {
				say UPD join ("\t", @output_row); 
			}
		}
	}
}


if ($download) {
	print "<tr><td><a href='$filename'>$filename</a></td></tr>";
	close UPD;
}
elsif ($view) {
	seek($tmp_fh,0,0);
	my $upd = do {local $/; <$tmp_fh>};
	print $upd;
	close $tmp_fh;
}


print '
	</table>
	</body>
	</html>';

sub init_handle {
	my $db = shift;

	# connecting to master since database may need to be created
	return
		DBI->connect(
		sprintf(
			"dbi:ODBC:Driver={SQL Server};Database=%s;Server=%s;UID=%s;PWD=%s",
			$db->{name}, $db->{server}, $db->{user}, $db->{pwd},
		)
		) or die "failed to initialize database handle\n", $DBI::errstr;
}

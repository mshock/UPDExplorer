#! perl -w

# TQASched web server

package WebServer;

use strict;
use feature 'say';

# share ISA across scope to webserver
our @ISA;

use base qw(HTTP::Server::Simple::CGI);

# for statically hosted files (css, js, etc.)
use HTTP::Server::Simple::Static;

# create a new instance of server
my $server = WebServer->new( 4242 );

say 'hold your hats, the server is starting up its jets';

# execute server process
$server->run();

#######################################################################
# point of no return - execution should never cross or server is dead
#######################################################################
# override request handler for HTTP::Server::Simple
sub handle_request {
	my ( $self, $cgi ) = @_;

		# parse POST into CLI argument key/value pairs
		# TODO: use AppConfig's CGI parser
		my $params_string = '';
		for ( $cgi->param ) {
				$params_string .= sprintf( '--%s="%s" ', $_, $cgi->param($_) )
				if defined $cgi->param($_);
		}

		# static serve web directory for css, generated charts (later, ajax)
		if ( $cgi->path_info =~ m/\.(css|xls|js|ico|jpg|gif)/i ) {
			$self->serve_static( $cgi, 'Resources' );
			return;
		}
		elsif ( $cgi->path_info =~ m/\.(upd)/i ) {
			$self->serve_static( $cgi, 'Files' );
			return;
		}		
		
		print `perl select_upd.pl $params_string`;

}

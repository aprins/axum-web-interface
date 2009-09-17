
package AXUM::Handler::Main;

use strict;
use warnings;
use YAWF ':html';


YAWF::register(
  qr{restart} => \&restart,
);


sub restart {
  my $self = shift;

#  system('su -c "/usr/bin/killall -9 axum-engine" < axum');
#  system('/etc/rc.d/axum-engine start');
  
  $self->resRedirect('/', 'post');
}


1;


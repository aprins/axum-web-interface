
package AXUM::Handler::Main;

use strict;
use warnings;
use YAWF ':html';


YAWF::register(
  qr{} => \&home,
);


sub home {
  my $self = shift;

  $self->htmlHeader(page => 'home');
  table;
   Tr; th ''; th 'Buss settings'; end;
   Tr; th '1'; td; a href => '/buss', 'Mix buss configuration'; end; end;
  end;
  $self->htmlFooter;
}


1;


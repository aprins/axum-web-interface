
package AXUM::Handler::Main;

use strict;
use warnings;
use YAWF ':html';


YAWF::register(
  qr{} => \&home,
);


sub home {
  my $self = shift;

  $self->htmlHeader(title => 'AXUM configuration pages', page => 'home');
  table;
   Tr; th ''; th 'Buss settings'; end;
   Tr; th 1; td; a href => '/buss', 'Mix buss configuration'; end; end;
   Tr; th 2; td; a href => '/monitorbuss', 'Monitor buss configuration'; end; end;
   Tr; th 3; td; a href => '/source', 'Source configuration'; end; end;
   Tr; th 4; td; a href => '/externsrc', 'Extern source configuration'; end; end;
   Tr; th 5; td; a href => '/dest', 'Destination configuration'; end; end;
  end;
  $self->htmlFooter;
}


1;


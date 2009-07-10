
package AXUM::Handler::Main;

use strict;
use warnings;
use YAWF ':html';


YAWF::register(
  qr{service} => \&service,
);


sub service {
  my $self = shift;

  $self->htmlHeader(title => 'AXUM service pages', page => 'service');
  table;
   Tr; th colspan => 2, 'Axum service'; end;
   Tr; th 1; td; a href => '/service/mambanet', 'MambaNet node overview'; end; end;
   Tr; th 2; td; a href => '/source/generate', 'Generate sources'; end; end;
   Tr; th 2; td; a href => '/dest/generate', 'Generate destinations'; end; end;
   Tr; th 2; td; a href => '/service/predefined', 'Stored configurations'; end; end;
  end;
  $self->htmlFooter;
}


1;


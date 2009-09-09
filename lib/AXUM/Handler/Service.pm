
package AXUM::Handler::Main;

use strict;
use warnings;
use YAWF ':html';


YAWF::register(
  qr{service} => \&service,
);


sub service {
  my $self = shift;

  $self->htmlHeader(title => $self->OEMName().' service pages', page => 'service');
  table;
   Tr; th colspan => 2, $self->OEMName().' service'; end;
   Tr; th 1; td; a href => '/service/mambanet', 'MambaNet node overview'; end; end;
   Tr; th 2; td; a href => '/source/generate', 'Generate sources'; end; end;
   Tr; th 3; td; a href => '/dest/generate', 'Generate destinations'; end; end;
   Tr; th 4; td; a href => '/service/predefined', 'Stored configurations'; end; end;
  end;
  $self->htmlFooter;
}


1;


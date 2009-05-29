
package AXUM::Handler::Main;

use strict;
use warnings;
use YAWF ':html';


YAWF::register(
  qr{} => \&home,
);


sub home {
  my $self = shift;

  $self->htmlHeader(title => 'AXUM Configuration Pages');
  h1 'Hello world!';
  $self->htmlFooter;
}


1;


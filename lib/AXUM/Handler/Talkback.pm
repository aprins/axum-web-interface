
package AXUM::Handler::Talkback;

use strict;
use warnings;
use YAWF ':html';


YAWF::register(
  qr{talkback} => \&talkback,
  qr{ajax/talkback} => \&ajax,
);


sub _col {
  my($d, $lst) = @_;
  my $v = $d->{source};
  a href => '#', onclick => sprintf('return conf_select("talkback", %d, "source", %d, this, "matrix_sources")', $d->{number}, $v),
    !$v || !$lst->[$v]{active} ? (class => 'off') : (), $v ? $lst->[$v]{label} : 'none';
}


sub talkback {
  my $self = shift;

  my $tb = $self->dbAll(q|SELECT number, source FROM talkback_config ORDER BY number|);
  my $pos_lst = $self->dbAll(q|SELECT number, type, label, active FROM matrix_sources ORDER BY pos|);
  my $src_lst = $self->dbAll(q|SELECT number, type, label, active FROM matrix_sources ORDER BY number|);

  $self->htmlHeader(page => 'talkback', title => 'Talkback configuration');
  $self->htmlSourceList($pos_lst, 'matrix_sources');
  table;
   Tr; th colspan => 2, 'Talkback configuration'; end;

   for (@$tb) {
     Tr;
      th "Talkback $_->{number}";
      td; _col $_, $src_lst; end;
     end;
   }
  end;
  $self->htmlFooter;
}


sub ajax {
  my $self = shift;

  my $src_lst = $self->dbAll('SELECT number, label, type, active FROM matrix_sources ORDER BY number');
  my $f = $self->formValidate(
    { name => 'field', template => 'asciiprint', enum => ['source'] },
    { name => 'item', template => 'int' },
    { name => 'source', required => 0, enum => [ 0, map $_->{number}, @$src_lst ] },
  );
  return 404 if $f->{_err};

  $self->dbExec('UPDATE talkback_config SET source = ? WHERE number = ?', $f->{source}, $f->{item}) if defined $f->{source};
  _col { number => $f->{item}, source => $f->{source} }, $src_lst;
}


1;


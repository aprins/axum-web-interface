
package AXUM::Handler::ExternSrc;

use strict;
use warnings;
use YAWF ':html';


YAWF::register(
  qr{externsrc} => \&extsrc,
  qr{ajax/externsrc} => \&ajax,
);


sub _col {
  my($n, $d, $lst) = @_;
  my $v = $d->{$n};
  a href => '#', onclick => sprintf('return conf_select("externsrc", %d, "%s", %d, this, "matrix_sources")', $d->{number}, $n, $v),
    !$v || !$lst->[$v-1]{active} ? (class => 'off') : (), $v ? $lst->[$v-1]{label} : 'none';
}


sub extsrc {
  my $self = shift;

  my $lst = $self->dbAll('SELECT number, label, type, active FROM matrix_sources ORDER BY number');
  my $mb = $self->dbAll('SELECT number, label, number <= dsp_count()*4 AS active
    FROM monitor_buss_config ORDER BY number');
  my $es = $self->dbAll('SELECT number, !s FROM extern_src_config ORDER BY number',
    join ', ', map "ext$_", 1..8);

  $self->htmlHeader(title => 'Extern source configuration', page => 'externsrc');
  $self->htmlSourceList($lst, 'matrix_sources');

  table;
   Tr; th colspan => 10, 'Extern source configuration'; end;
   Tr;
    th colspan => 2, 'Monitor bus';
    th colspan => 8, 'Extern source';
   end;
   Tr;
    th 'Nr.';
    th 'Label';
    th "Ext $_" for (1..8);
   end;

   for my $m (@$mb) {
     Tr $m->{active} ? () : (class => 'inactive');
      th $m->{number};
      td $m->{label};
      $m->{number} % 4 == 1 and do {for (1..8) {
        td rowspan => 4; _col "ext$_", $es->[($m->{number}-1)/4], $lst; end;
      }};
     end;
   }
  end;
  $self->htmlFooter;
}


sub ajax {
  my $self = shift;

  my $lst = $self->dbAll('SELECT number, label, type, active FROM matrix_sources ORDER BY number');
  my $enum = [ 0, map $_->{number}, @$lst ];
  my $f = $self->formValidate(
    { name => 'field', template => 'asciiprint' },
    { name => 'item', template => 'int' },
    map +{ name => "ext$_", required => 0, enum => $enum }, 1..8
  );
  return 404 if $f->{_err};

  my %set;
  defined $f->{"ext$_"} and ($set{"ext$_ = ?"} = $f->{"ext$_"})
    for(1..8);

  $self->dbExec('UPDATE extern_src_config !H WHERE number = ?', \%set, $f->{item}) if keys %set;
  _col $f->{field}, { number => $f->{item}, $f->{field} => $f->{$f->{field}} }, $lst;
}


1;


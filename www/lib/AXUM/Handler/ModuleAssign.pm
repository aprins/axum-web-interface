
package AXUM::Handler::ModuleAssign;

use strict;
use warnings;
use YAWF ':html';


YAWF::register(
  qr{module/assign} => \&assign,
  qr{ajax/module/assign} => \&ajax,
);


my @busses = map sprintf('buss_%d_%d_assignment', $_*2-1, $_*2), 1..16;


sub _col {
  my($n, $d) = @_;
  my $v = $d->{$n};
  a href => '#', onclick => sprintf('return conf_set("module/assign", %d, "%s", "%s", this)', $d->{number}, $n, $v?0:1),
    $v ? 'y' : (class => 'off', 'n');
}


sub assign {
  my $self = shift;

  my $p = $self->formValidate({name => 'p', required => 0, default => 1, enum => [1..4]});
  return 404 if $p->{_err};
  $p = $p->{p};

  my $bus = $self->dbAll('SELECT number, label FROM buss_config ORDER BY number');
  my $mod = $self->dbAll('SELECT number, !s FROM module_config WHERE number >= ? AND number <= ? ORDER BY number',
    join(', ', @busses), $p*32-31, $p*32);
  my $dspcount = $self->dbRow('SELECT dsp_count() AS cnt')->{cnt};

  $self->htmlHeader(page => 'moduleassign', title => 'Module assignment');
  table;
   Tr;
    th colspan => 33;
     p class => 'navigate';
      txt 'Page: ';
      a href => "?p=$_", $p == $_ ? (class => 'sel') : (), $_
        for (1..4);
     end;
     txt 'Module assignment';
    end;
   end;
   Tr $p > $dspcount ? (class => 'inactive') : ();
    th 'Buss';
    th style => 'padding: 1px 0; width: 20px', $_->{number}
      for (@$mod);
   end;
   for my $b (@$bus) {
     Tr $p > $dspcount ? (class => 'inactive') : ();
      th $b->{label};
      for (@$mod) {
        td;
         _col $busses[$b->{number}-1], $_;
        end;
      }
     end;
   }
  end;
  $self->htmlFooter;
}


sub ajax {
  my $self = shift;

  my $f = $self->formValidate(
    { name => 'field', template => 'asciiprint' },
    { name => 'item', template => 'int' },
    map +{ name => $_, required => 0, enum => [0,1] }, @busses
  );
  return 404 if $f->{_err};

  my %set = map +("$_ = ?", $f->{$_}), grep defined $f->{$_}, @busses;
  $self->dbExec('UPDATE module_config !H WHERE number = ?', \%set, $f->{item});
  _col $f->{field}, { number => $f->{item}, $f->{field} => $f->{$f->{field}} };
}


1;


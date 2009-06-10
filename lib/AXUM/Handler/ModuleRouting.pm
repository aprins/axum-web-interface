
package AXUM::Handler::ModuleRouting;

use strict;
use warnings;
use YAWF ':html';


YAWF::register(
  qr{module/([1-9][0-9]*)/route} => \&route,
  qr{ajax/module/route} => \&ajax,
);


my @busses = map sprintf('buss_%d_%d', $_*2-1, $_*2), 1..16;
my @balance = ('left', 'center', 'right');


sub _col {
  my($n, $d) = @_;
  my $v = $d->{$n};
  if($n =~ /level$/) {
    a href => '#', onclick => sprintf('return conf_level("module/route", %d, "%s", %f, this)', $d->{number}, $n, $v),
      $v == 0 ? (class => 'off') : (), sprintf '%.1f dB', $v;
  }
  if($n =~ /on_off$/) {
    a href => '#', onclick => sprintf('return conf_set("module/route", %d, "%s", "%s", this)', $d->{number}, $n, $v?0:1),
      !$v ? (class => 'off', 'off') : 'on';
  }
  if($n =~ /pre_post$/) {
    a href => '#', onclick => sprintf('return conf_set("module/route", %d, "%s", "%s", this)', $d->{number}, $n, $v?0:1),
      !$v ? (class => 'off', 'post') : 'pre';
  }
  if($n =~ /balance$/) {
    $v = sprintf '%.0f', $v/512;
    a href => '#', onclick => sprintf('return conf_select("module/route", %d, "%s", %d, this, "balance_items")',
      $d->{number}, $n, $v), $v == 1 ? (class => 'off') : (), $balance[$v];
  }
}


sub route {
  my($self, $nr) = @_;

  my $bus = $self->dbAll('SELECT number, label FROM buss_config ORDER BY number');
  my $mod = $self->dbRow('SELECT number, !s FROM module_config WHERE number = ?',
    join(', ', map +("${_}_level", "${_}_on_off", "${_}_pre_post", "${_}_balance", "${_}_assignment"), @busses), $nr);
  return 404 if !$mod->{number};

  $self->htmlHeader(page => 'modulerouting', section => $nr, title => "Module $nr routing configuration");
  div id => 'balance_items', class => 'hidden';
   Select;
    option value => $_, $balance[$_] for (0..$#balance);
   end;
  end;
  table;
   Tr; th colspan => 5, "Module $nr routing configuration"; end;
   Tr;
    th 'Buss';
    th 'Level';
    th 'State';
    th 'Pre/post';
    th 'Balance';
   end;
   for my $b (@$bus) {
     next if !$mod->{$busses[$b->{number}-1].'_assignment'};
     Tr;
      th $b->{label};
      td; _col $busses[$b->{number}-1].'_level', $mod; end;
      td; _col $busses[$b->{number}-1].'_on_off', $mod; end;
      td; _col $busses[$b->{number}-1].'_pre_post', $mod; end;
      td; _col $busses[$b->{number}-1].'_balance', $mod; end;
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
    map +(
      { name => "${_}_level", required => 0 },
      { name => "${_}_on_off", required => 0, enum => [0,1] },
      { name => "${_}_pre_post", required => 0, enum => [0,1] },
      { name => "${_}_balance", required => 0, enum => [0..2] },
    ), @busses
  );

  my %set;
  defined $f->{$_} && ($f->{$_} *= 511)
    for (map "${_}_balance", @busses);
  defined $f->{$_} && ($set{"$_ = ?"} = $f->{$_})
    for (map +("${_}_level", "${_}_on_off", "${_}_pre_post", "${_}_balance"), @busses);
  $self->dbExec('UPDATE module_config !H WHERE number = ?', \%set, $f->{item}) if keys %set;
  _col $f->{field}, { number => $f->{item}, $f->{field} => $f->{$f->{field}} };
}


1;


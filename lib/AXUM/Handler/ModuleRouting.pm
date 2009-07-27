
package AXUM::Handler::ModuleRouting;

use strict;
use warnings;
use YAWF ':html';
use Data::Dumper 'Dumper';


YAWF::register(
  qr{module/([1-9][0-9]*)/route} => \&route,
  qr{ajax/module/route/([1-8])} => \&ajax,
);


my @busses = map sprintf('buss_%d_%d', $_*2-1, $_*2), 1..16;
my @balance = ('left', 'center', 'right');


sub _col {
  my($n, $p, $d) = @_;
  my $v = $d->{$n};
  if($n =~ /level$/) {
    a href => '#', onclick => sprintf('return conf_level("module/route/%d", %d, "%s", %f, this)', $p, $d->{number}, $n, $v),
      $v == 0 ? (class => 'off') : (), sprintf '%.1f dB', $v;
  }
  if($n =~ /on_off$/) {
    a href => '#', onclick => sprintf('return conf_set("module/route/%d", %d, "%s", "%s", this)', $p, $d->{number}, $n, $v?0:1),
      !$v ? (class => 'off', 'off') : 'on';
  }
  if($n =~ /pre_post$/) {
    a href => '#', onclick => sprintf('return conf_set("module/route/%d", %d, "%s", "%s", this)', $p, $d->{number}, $n, $v?0:1),
      !$v ? (class => 'off', 'post') : 'pre';
  }
  if($n =~ /balance$/) {
    $v = sprintf '%.0f', $v/512;
    a href => '#', onclick => sprintf('return conf_select("module/route/%d", %d, "%s", %d, this, "balance_items")', $p,
      $d->{number}, $n, $v), $v == 1 ? (class => 'off') : (), $balance[$v];
  }
}


sub route {
  my($self, $nr) = @_;

  my $p = $self->formValidate({name => 'p', required => 0, default => 1, enum => [1..8]});
  return 404 if $p->{_err};
  $p = $p->{p};

  my $bus = $self->dbAll('SELECT number, label FROM buss_config ORDER BY number');
  my $mod = $self->dbRow('SELECT number, !s FROM module_config WHERE number = ?',
    join(', ', map +("${_}_level[$p]", "${_}_on_off[$p]", "${_}_pre_post[$p]", "${_}_balance[$p]", "${_}_assignment"), @busses), $nr);
  return 404 if !$mod->{number};

  $self->htmlHeader(page => 'modulerouting', section => $nr, title => "Module $nr routing configuration");
  div id => 'balance_items', class => 'hidden';
   Select;
    option value => $_, $balance[$_] for (0..$#balance);
   end;
  end;
  table;
   Tr;
    th colspan => 5;
     txt "Module $nr routing configuration";
     p class => 'navigate';
      txt 'preset: ';
      a href => "?p=1", $p == 1 ? (class => 'sel') : (), 'Default';
      a href => "?p=$_", $p == $_ ? (class => 'sel') : (), $_
        for (2..8);
     end;
    end;
   end;
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
      td; _col $busses[$b->{number}-1].'_level', $p, $mod; end;
      td; _col $busses[$b->{number}-1].'_on_off', $p, $mod; end;
      td; _col $busses[$b->{number}-1].'_pre_post', $p, $mod; end;
      td; _col $busses[$b->{number}-1].'_balance', $p, $mod; end;
     end;
   }
  end;
  $self->htmlFooter;
}


sub ajax {
  my($self, $p) = @_;

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
  return 404 if $f->{_err};

  my %set;
  defined $f->{$_} && ($f->{$_} *= 511)
    for (map "${_}_balance", @busses);
  defined $f->{$_} && ($set{$_."[$p] = ?" } = $f->{$_})
    for (map +("${_}_level", "${_}_on_off", "${_}_pre_post", "${_}_balance"), @busses);

  $self->dbExec('UPDATE module_config !H WHERE number = ?', \%set, $f->{item}) if keys %set;
  _col $f->{field}, $p, { number => $f->{item}, $f->{field} => $f->{$f->{field}} };
}


1;


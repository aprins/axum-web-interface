
package AXUM::Handler::MonitorBuss;

use strict;
use warnings;
use YAWF ':html';


YAWF::register(
  qr{monitorbuss} => \&monitorbuss,
  qr{ajax/monitorbuss} => \&ajax,
);


my @busses = map sprintf('buss_%d_%d', $_*2-1, $_*2), 1..16;


sub _selection {
  return [
   (map $_->{label}, @{shift->dbAll('SELECT label FROM buss_config ORDER BY number')}),
   (map "Ext $_", 1..8)
  ];
}


# arguments: field name, db return object, (+selection list for default_selection)
sub _col {
  my($n, $d) = @_;
  my $v = $d->{$n};

  if($n eq 'label') {
    (my $jsval = $v) =~ s/\\/\\\\/g;
    $jsval =~ s/"/\\"/g;
    a href => '#', onclick => sprintf('return conf_text("monitorbuss", %d, "label", "%s", this)', $d->{number}, $jsval), $v;
  }
  if($n eq 'interlock') {
    a href => '#', onclick => sprintf('return conf_set("monitorbuss", %d, "interlock", "%s", this)', $d->{number}, $v?0:1),
      !$v ? (class => 'off', 'no') : 'yes';
  }
  if($n =~ /buss_/) {
    a href => '#', onclick => sprintf('return conf_set("monitorbuss", %d, "%s", "%s", this)', $d->{number}, $n, $v?0:1),
      !$v ? (class => 'off', 'n') : 'y';
  }
  if($n eq 'dim_level') {
    a href => '#', onclick => sprintf('return conf_level("monitorbuss", %d, "dim_level", %f, this)', $d->{number}, $v),
      $v == 0 ? (class => 'off') : (), sprintf '%.1f dB', $v;
  }
  if($n eq 'default_selection') {
    a href => '#', onclick => sprintf(
      'return conf_select("monitorbuss", %d, "default_selection", %d, this, default_selection_items)',
      $d->{number}, $v), $_[2][$v];
  }
}


sub monitorbuss {
  my $self = shift;

  my $sel = _selection $self;
  my $busses = $self->dbAll('SELECT number, label FROM buss_config ORDER BY number');
  my $mb = $self->dbAll('SELECT number, label, interlock, default_selection, dim_level, !s,
    number <= dsp_count()*4 AS active FROM monitor_buss_config ORDER BY number', join ', ', @busses);

  $self->htmlHeader(title => 'Monitor buss configuraiton', page => 'monitorbuss');
  # create JS array for the options for default_selection
  script type => 'text/javascript';
   lit 'default_selection_items = ['.join(',', map {
     (my $v = $sel->[$_]) =~ s/\\/\\\\/g;
     $v =~ s/"/\\"/g;
     qq|[$_,"$v"]|
   } 0..$#$sel).'];';
  end;

  table;
   Tr; th colspan => 21, 'Monitor buss configuration'; end;
   Tr;
    th colspan => 3, '';
    th rowspan => 2, "Default\nselection";
    th colspan => 17, 'Automatic switching';
   end;
   Tr;
    th 'Nr.';
    th 'Label';
    th 'Interlock';
    th id => "exp_$_->{number}", abbr => $_->{label}, $_->{number}%10
      for (@$busses);
    th 'Dim level';
   end;

   for my $m (@$mb) {
     Tr $m->{active} ? () : (class => 'inactive');
      th $m->{number};
      td; _col 'label', $m; end;
      td; _col 'interlock', $m; end;
      td; _col 'default_selection', $m, $sel; end;
      for (@$busses) {
        td class => "exp_$_->{number}";
         _col $busses[$_->{number}-1], $m;
        end;
      }
      td; _col 'dim_level', $m; end;
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
    { name => 'label', required => 0, maxlength => 32, minlength => 1 },
    { name => 'interlock', required => 0, enum => [0,1] },
    { name => 'default_selection', required => 0, template => 'int' },
    { name => 'dim_level', required => 0, regex => [ qr/-?[0-9]*(\.[0-9]+)?/, 0 ] },
    map +{ name => $_, required => 0, enum => [0,1] }, @busses
  );
  return 404 if $f->{_err};

  my %set;
  defined $f->{$_} and ($set{"$_ = ?"} = $f->{$_})
    for(qw|label interlock default_selection dim_level|, @busses);

  $self->dbExec('UPDATE monitor_buss_config !H WHERE number = ?', \%set, $f->{item}) if keys %set;
  _col $f->{field}, { number => $f->{item}, $f->{field} => $f->{$f->{field}} },
    $f->{field} eq 'default_selection' ? _selection $self : undef;
}


1;


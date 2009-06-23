
package AXUM::Handler::Buss;

use strict;
use warnings;
use YAWF ':html';


YAWF::register(
  qr{buss}      => \&buss,
  qr{ajax/buss} => \&ajax,
);


# display the value of a column
# arguments: column name, database return object
sub _col {
  my($n, $d) = @_;
  my $v = $d->{$n};

  # boolean values
  my %booleans = (
    global_reset => [0, 'yes', 'no'  ],
    interlock    => [0, 'yes', 'no'  ],
    on_off       => [1, 'On',  'Off' ],
    pre_on       => [0, 'Pre', 'Post'],
    pre_level    => [0, 'Pre', 'Post'],
    pre_balance  => [0, 'Pre', 'Post'],
  );

  if($booleans{$n}) {
    a href => '#', onclick => sprintf('return conf_set("buss", %d, "%s", "%s", this)', $d->{number}, $n, $v?0:1),
      ($v?1:0) == $booleans{$n}[0] ? (class => 'off') : (), $booleans{$n}[$v?1:2];
    return;
  }
  if($n eq 'level') {
    a href => '#', onclick => sprintf('return conf_level("buss", %d, "level", %f, this)', $d->{number}, $v),
      $v == 0 ? (class => 'off') : (), sprintf '%.1f dB', $v;
  }
  if($n eq 'label') {
    (my $jsval = $v) =~ s/\\/\\\\/g;
    $jsval =~ s/"/\\"/g;
    a href => '#', onclick => sprintf('return conf_text("buss", %d, "label", "%s", this)', $d->{number}, $jsval), $v;
  }
}


sub buss {
  my $self = shift;

  my $busses = $self->dbAll(q|
    SELECT number, label, pre_on, pre_level, pre_balance, level, on_off, interlock, global_reset
      FROM buss_config ORDER BY number ASC|);

  $self->htmlHeader(title => 'Buss configuration', page => 'buss');
  table;
   Tr; th colspan => 9, 'Buss configuration'; end;
   Tr;
    th colspan => 2, '';
    th colspan => 3, 'Master Pre/Post';
    th colspan => 2, 'Master';
    th '';
    th rowspan => 2, "Buss reset\nby module active";
   end;
   Tr;
    th 'Buss';
    th 'Label';
    th 'Module on';
    th 'Module level';
    th 'Module balance';
    th 'Level';
    th 'State';
    th 'Interlock';
   end;
   for my $b (@$busses) {
     Tr;
      th sprintf '%d/%d', $b->{number}*2-1, $b->{number}*2;
      for(qw|label pre_on pre_level pre_balance level on_off interlock global_reset|) {
        td; _col $_, $b; end;
      }
     end;
   }
  end;
  $self->htmlFooter;
}


sub ajax {
  my $self = shift;

  my $f = $self->formValidate(
    { name => 'field', template => 'asciiprint' }, # should have an enum property
    { name => 'item', template => 'int' },
    { name => 'global_reset', required => 0, enum => [0,1] },
    { name => 'interlock',    required => 0, enum => [0,1] },
    { name => 'on_off',       required => 0, enum => [0,1] },
    { name => 'pre_on',       required => 0, enum => [0,1] },
    { name => 'pre_level',    required => 0, enum => [0,1] },
    { name => 'pre_balance',  required => 0, enum => [0,1] },
    { name => 'level',        required => 0, regex => [ qr/-?[0-9]*(\.[0-9]+)?/, 0 ] },
    { name => 'label',        required => 0, maxlength => 32, minlength => 1 },
  );
  return 404 if $f->{_err};

  my %set;
  defined $f->{$_} and ($set{"$_ = ?"} = $f->{$_})
    for(qw|global_reset interlock on_off pre_on pre_level pre_balance level label|);

  $self->dbExec('UPDATE buss_config !H WHERE number = ?', \%set, $f->{item}) if keys %set;
  _col $f->{field}, { number => $f->{item}, $f->{field} => $f->{$f->{field}} };
}


1;


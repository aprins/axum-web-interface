
package AXUM::Handler::Source;

use strict;
use warnings;
use YAWF ':html';


YAWF::register(
  qr{source}      => \&source,
  qr{ajax/source} => \&ajax,
);


sub _channels {
  return shift->dbAll(q|SELECT s.addr, a.active, s.slot_nr, g.channel, a.name
    FROM slot_config s
    JOIN addresses a ON a.addr = s.addr
    JOIN generate_series(1,32) AS g(channel) ON s.input_ch_cnt >= g.channel
    WHERE input_ch_cnt > 0
    ORDER BY a.name, g.channel
  |);
}


sub _col {
  my($n, $d) = @_;
  my $v = $d->{$n};

  if($n eq 'label') {
    (my $jsval = $v) =~ s/\\/\\\\/g;
    $jsval =~ s/"/\\"/g;
    a href => '#', onclick => sprintf('return conf_text("source", %d, "label", "%s", this)', $d->{number}, $jsval), $v;
  }
  if($n eq 'gain') {
    a href => '#', onclick => sprintf('return conf_level("source", %d, "gain", %f, this)', $d->{number}, $v),
      $v == 0 ? (class => 'off') : (), sprintf '%.1f dB', $v;
  }
  if($n eq 'phantom' || $n eq 'pad') {
    a href => '#', onclick => sprintf('return conf_set("source", %d, "%s", "%s", this)', $d->{number}, $n, $v?0:1),
      !$v ? (class => 'off', 'no') : 'yes';
  }
  if($n =~ /(?:redlight|monitormute)/) {
    a href => '#', onclick => sprintf('return conf_set("source", %d, "%s", "%s", this)', $d->{number}, $n, $v?0:1),
      !$v ? (class => 'off', 'n') : 'y';
  }
  if($n =~ /input([12])/) {
    $v = (grep $_->{addr} == $d->{'input'.$1.'_addr'} && $_->{channel} == $d->{'input'.$1.'_sub_ch'}, @{$_[2]})[0];
    a href => '#', $v->{active} ? () : (class => 'off'), onclick => sprintf(
      'return conf_select("source", %d, "%s", "%s", this, "input_channels")', $d->{number}, $n, "$v->{addr}_$v->{channel}"),
      sprintf('Slot %d ch %d', $v->{slot_nr}, $v->{channel});
  }
}


sub _create_source {
  my($self, $chan) = @_;

  my $f = $self->formValidate(
    { name => 'input1', enum => [ map "$_->{addr}_$_->{channel}", @$chan ] },
    { name => 'input2', enum => [ map "$_->{addr}_$_->{channel}", @$chan ] },
    { name => 'label', minlength => 1, maxlength => 32 },
  );
  die "Invalid input" if $f->{_err};
  my @inputs = (split(/_/, $f->{input1}), split(/_/, $f->{input2}));

  # get new free source number
  my $num = $self->dbRow(q|SELECT gen
    FROM generate_series(1, COALESCE((SELECT MAX(number)+1 FROM src_config), 1)) AS g(gen)
    WHERE NOT EXISTS(SELECT 1 FROM src_config WHERE number = gen)
    LIMIT 1|
  )->{gen};
  # insert row
  $self->dbExec(q|
    INSERT INTO src_config (number, label, input1_addr, input1_sub_ch, input2_addr, input2_sub_ch) VALUES (!l)|,
    [ $num, $f->{label}, @inputs ]);
}


sub source {
  my $self = shift;

  my $chan = _channels $self;

  # if POST, insert new source
  _create_source($self, $chan) if $self->reqMethod eq 'POST';

  # if del, remove source
  my $f = $self->formValidate({name => 'del', template => 'int'});
  if(!$f->{_err}) {
    $self->dbExec('DELETE FROM src_config WHERE number = ?', $f->{del});
    return $self->resRedirect('/source');
  }

  my $mb = $self->dbAll(q|SELECT number, label FROM monitor_buss_config ORDER BY number|);

  my @cols = ((map "redlight$_", 1..8), (map "monitormute$_", 1..16));
  my $src = $self->dbAll(q|SELECT number, label, input1_addr, input1_sub_ch, input2_addr,
    input2_sub_ch, phantom, pad, gain, !s FROM src_config ORDER BY number|, join ', ', @cols);

  $self->htmlHeader(title => 'Source configuration', page => 'source');
  # create list of available channels for javascript
  div id => 'input_channels', class => 'hidden';
   Select;
    option value => "$_->{addr}_$_->{channel}",
        sprintf "Slot %d channel %d (%s)", $_->{slot_nr}, $_->{channel}, $_->{name}
      for @$chan;
   end;
  end;

  table;
   Tr; th colspan => 32, 'Source configuration'; end;
   Tr;
    th '';
    th colspan => 6, '';
    th colspan => 8, 'Redlight';
    th colspan => 16, 'Monitor destination mute/dim';
    th '';
   end;
   Tr;
    th 'Nr.';
    th 'Label';
    th 'Input 1 (left)';
    th 'Input 2 (right)';
    th 'Phantom';
    th 'Pad';
    th 'Gain';
    th $_ for (1..8);
    th abbr => $_->{label}, id => "exp_monitormute$_->{number}", $_->{number}%10
      for (@$mb);
    th '';
   end;

   for my $s (@$src) {
     Tr;
      th $s->{number};
      td; _col 'label', $s; end;
      td; _col 'input1', $s, $chan; end;
      td; _col 'input2', $s, $chan; end;
      for (qw|phantom pad gain|, map "redlight$_", 1..8) {
        td; _col $_, $s; end;
      }
      for (map "monitormute$_", 1..16) {
        td class => "exp_$_"; _col $_, $s; end;
      }
      td;
       a href => '/source?del='.$s->{number}, title => 'Delete';
        img src => '/images/delete.png', alt => 'delete';
       end;
      end;
     end;
   }
  end;
  br; br;
  a href => '#', onclick => 'return conf_addsrcdest(this, "input_channels", "input")', 'Create new source';

  $self->htmlFooter;
}


sub ajax {
  my $self = shift;

  my $f = $self->formValidate(
    { name => 'field', template => 'asciiprint' },
    { name => 'item', template => 'int' },
    { name => 'label', required => 0, maxlength => 32, minlength => 1 },
    { name => 'phantom', required => 0, enum => [0,1] },
    { name => 'pad', required => 0, enum => [0,1] },
    { name => 'gain', required => 0, regex => [ qr/-?[0-9]*(\.[0-9]+)?/, 0 ] },
    { name => 'input1', required => 0, regex => [ qr/[0-9]+_[0-9]+/, 0 ] },
    { name => 'input2', required => 0, regex => [ qr/[0-9]+_[0-9]+/, 0 ] },
    (map +{ name => "redlight$_", required => 0, enum => [0,1] }, 1..8),
    (map +{ name => "monitormute$_", required => 0, enum => [0,1] }, 1..16),
  );
  return 404 if $f->{_err};

  my %set;
  defined $f->{$_} and ($set{"$_ = ?"} = $f->{$_})
    for(qw|label phantom pad gain|, (map "redlight$_", 1..8), (map "monitormute$_", 1..16));
  defined $f->{$_} and $f->{$_} =~ /([0-9]+)_([0-9]+)/ and ($set{$_.'_addr = ?, '.$_.'_sub_ch = ?'} = [ $1, $2 ])
    for('input1', 'input2');

  $self->dbExec('UPDATE src_config !H WHERE number = ?', \%set, $f->{item}) if keys %set;
  if($f->{field} =~ /(input[12])/) {
    my @l = split /_/, $f->{$f->{field}};
    _col $f->{field}, { number => $f->{item}, $1.'_addr' => $l[0], $1.'_sub_ch' => $l[1] }, _channels $self;
  } else {
    _col $f->{field}, { number => $f->{item}, $f->{field} => $f->{$f->{field}} };
  }
}



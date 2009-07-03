#
package AXUM::Handler::Source;

use strict;
use warnings;
use YAWF ':html';


YAWF::register(
  qr{source}            => \&source,
  qr{source/generate}   => \&generate,
  qr{ajax/source}       => \&ajax,
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

  if($n eq 'pos') {
    a href => '#', onclick => sprintf('return conf_select("source", %d, "%s", "%s", this, "source_list")', $d->{number}, $n, "$d->{pos}"), $d->{pos};
  }
  if($n eq 'label') {
    (my $jsval = $v) =~ s/\\/\\\\/g;
    $jsval =~ s/"/\\"/g;
    a href => '#', onclick => sprintf('return conf_text("source", %d, "label", "%s", this)', $d->{number}, $jsval), $v;
  }
  if($n eq 'gain') {
    a href => '#', onclick => sprintf('return conf_level("source", %d, "gain", %f, this)', $d->{number}, $v),
      $v == 30 ? (class => 'off') : (), sprintf '%.1f dB', $v;
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
  $self->dbExec("SELECT src_config_renumber()");
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
    $self->dbExec("SELECT src_config_renumber()");
    return $self->resRedirect('/source');
  }
  
  my $mb = $self->dbAll('SELECT number, label, number <= dsp_count()*4 AS active
    FROM monitor_buss_config ORDER BY number');

  my @cols = ((map "redlight$_", 1..8), (map "monitormute$_", 1..16));
  my $src = $self->dbAll(q|SELECT pos, number, label, input1_addr, input1_sub_ch, input2_addr,
    input2_sub_ch, phantom, pad, gain, !s FROM src_config ORDER BY pos|, join ', ', @cols);

  $self->htmlHeader(title => 'Source configuration', page => 'source');
  # create list of available channels for javascript
  div id => 'input_channels', class => 'hidden';
   Select;
    option value => "$_->{addr}_$_->{channel}",
        sprintf "Slot %d channel %d (%s)", $_->{slot_nr}, $_->{channel}, $_->{name}
      for @$chan;
   end;
  end;
  # create list of sources for javascript
  div id => 'source_list', class => 'hidden';
   Select;
   my $max_pos;
    $max_pos = 0;
    for (@$src) {
      option value => "$_->{pos}", $_->{label};
      $max_pos = $_->{pos} if ($_->{pos} > $max_pos);
    }
    option value => $max_pos+1, "last";
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
    th 'Nr';
    th 'Label';
    th 'Input 1 (left)';
    th 'Input 2 (right)';
    th 'Phantom';
    th 'Pad';
    th 'Gain';
    th $_ for (1..8);
    th abbr => $_->{label}, $_->{active} ? ():(class => 'inactive'), id => "exp_monitormute$_->{number}", $_->{number}%10
      for (@$mb);
    th '';
   end;

   for my $s (@$src) {
     Tr;
      th; _col 'pos', $s; end;
      td; _col 'label', $s; end;
      td; _col 'input1', $s, $chan; end;
      td; _col 'input2', $s, $chan; end;
      for (qw|phantom pad gain|, map "redlight$_", 1..8) {
        td; _col $_, $s; end;
      }
      for (@$mb) {
        td $_->{active} ? (class => "exp_monitormute$_->{number}") : (class => "exp_monitormute$_->{number} inactive"); _col "monitormute$_->{number}", $s; end;
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
  #a href => '/source/generate', 'Delete sources and generate them from the rack layout';

  $self->htmlFooter;
}

sub generate {
  my $self = shift;

  my $cards = $self->dbAll('SELECT a.addr, a.name, s.slot_nr, s.input_ch_cnt, a.active
    FROM slot_config s JOIN addresses a ON a.addr = s.addr WHERE s.input_ch_cnt <> 0 ORDER BY s.slot_nr');

  $self->htmlHeader(title => 'Generate sources', page => 'source', section => 'generate');
  table;
   Tr; th colspan => 8, 'Generate sources'; end;
   Tr;
    th 'Slot';
    th 'Card name';
    th 'Inputs';
    th 'Mono';
   end;
   for my $c (@$cards) {
     Tr !$c->{active} ? (class => 'inactive') : ();
      th rowspan => $c->{input_ch_cnt}, $c->{slot_nr};
      td rowspan => $c->{input_ch_cnt}, $c->{name};
      td '1';
      td;
       input type => 'checkbox';
      end;
     end;
     my $i;
     for ($i=2; $i<=$c->{input_ch_cnt}; $i++)
     {
       Tr;
        td $i;
        td;
         input type => 'checkbox';
        end;
       end;
     }
   }
  end;
  br;
  input type => 'button', value => 'generate';
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
    { name => 'pos', required => 0, 'int' },
  );
  return 404 if $f->{_err};

  #if field returned is 'nr', the positions of other rows may change...
  if($f->{field} eq 'pos') {
    $self->dbExec("UPDATE src_config SET pos =
                   CASE
                    WHEN pos < $f->{pos} AND number <> $f->{item} THEN pos
                    WHEN pos >= $f->{pos} AND number <> $f->{item} THEN pos+1
                    WHEN number = $f->{item} THEN $f->{pos}
                    ELSE 9999
                   END;");
    $self->dbExec("SELECT src_config_renumber();");
    #_col $f->{field}, { number => $f->{item}, $f->{field} => $f->{$f->{field}} };
    txt 'Wait for reload';
  } else {
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
}

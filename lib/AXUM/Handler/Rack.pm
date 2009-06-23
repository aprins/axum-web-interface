
package AXUM::Handler::Rack;

use strict;
use warnings;
use YAWF ':html';


YAWF::register(
  qr{rack} => \&list,
  qr{rack/([0-9a-f]{8})} => \&conf,
  qr{ajax/func} => \&funclist,
  qr{ajax/setfunc} => \&setfunc,
);


my @mbn_types = ('no data', 'unsigned int', 'signed int', 'state', 'octet string', 'float', 'bit string');


sub list {
  my $self = shift;

  my $cards = $self->dbAll('SELECT a.addr, a.name, s.slot_nr, s.input_ch_cnt, s.output_ch_cnt, a.active
    FROM slot_config s JOIN addresses a ON a.addr = s.addr ORDER BY s.slot_nr');

  $self->htmlHeader(title => 'Rack configuration', page => 'rack');
  table;
   Tr; th colspan => 6, 'Rack configuration'; end;
   Tr;
    th 'Slot';
    th 'MambaNet Address';
    th 'Card name';
    th 'Inputs';
    th 'Outputs';
    th 'Settings';
   end;
   for my $c (@$cards) {
     Tr !$c->{active} ? (class => 'inactive') : ();
      th $c->{slot_nr};
      td sprintf '%08X', $c->{addr};
      td $c->{name};
      td $c->{input_ch_cnt};
      td $c->{output_ch_cnt};
      td;
       a href => sprintf('/rack/%08x', $c->{addr}); lit 'configure &raquo;'; end;
      end;
     end;
   }
  end;
  $self->htmlFooter;
}


sub _funcname {
  my($self, $addr, $num, $f1, $f2, $f3, $sens, $act, $buss) = @_;
  a href => '#', onclick => sprintf('return conf_func("%s", %d, %d, %d, %d, %d, %d, this)',
    $addr, $num, $f1, $f2, $f3, $sens, $act), $f1 == -1 ? (class => 'off') : ();
   if($f1 == -1) {
     txt 'not configured';
   } else {
     my $name = $self->dbRow('SELECT name FROM functions WHERE (func).type = ? AND (func).func = ?', $f1, $f3)->{name};
     $name =~ s{Buss \d+/(\d+)}{$buss->[$1/2-1]}ieg;
     txt 'Module '.($f2+1).': ' if $f1 == 0;
     txt $buss->[$f2].': ' if $f1 == 1;
     txt $self->dbRow('SELECT label FROM monitor_buss_config WHERE number = ?', $f2+1)->{label}.': ' if $f1 == 2;
     txt $self->dbRow('SELECT label FROM src_config WHERE number = ?', $f2+1)->{label}.': ' if $f1 == 5;
     txt $self->dbRow('SELECT label FROM dest_config WHERE number = ?', $f2+1)->{label}.': ' if $f1 == 6;
     txt $name;
   }
  end;
}


sub conf {
  my($self, $addr) = @_;
  $addr = uc $addr;

  my $objects = $self->dbAll('
      SELECT t.number, t.description, t.sensor_type, t.actuator_type, t.actuator_def, d.data, c.func
      FROM templates t
      JOIN addresses a ON (t.man_id = (a.id).man AND t.prod_id = (a.id).prod AND t.firm_major = a.firm_major)
      LEFT JOIN defaults d ON (d.addr = a.addr AND t.number = d.object)
      LEFT JOIN node_config c ON (c.addr = a.addr AND t.number = c.object)
      WHERE a.addr = ? ORDER BY t.number',
    oct "0x$addr"
  );
  my $buss = [ map $_->{label}, @{$self->dbAll('SELECT label FROM buss_config ORDER BY number')} ];

  $self->htmlHeader(page => 'objects', section => $addr, title => "Object configuration for $addr");
  table;
   Tr; th colspan => 6, "Object configuration for $addr"; end;
   Tr;
    th 'Nr.';
    th 'Description';
    th 'Type';
    th 'Default';
    th 'Function';
   end;
   for my $o (@$objects) {
     Tr;
      th $o->{number};
      td $o->{description};
      td join ' + ', $o->{sensor_type} ? 'sensor' : (), $o->{actuator_type} ? 'actuator' : ();
      td $o->{data} || $o->{actuator_def}; # TODO: make configurable, etc
      td;
       _funcname $self, $addr, $o->{number},
         $o->{func} && $o->{func} =~ /(\d+),(\d+),(\d+)/ ? ($1, $2, $3) : (-1,0,0),
         $o->{sensor_type}, $o->{actuator_type}, $buss;
      end;
     end;
   }
  end;
  $self->htmlFooter;
}


sub funclist {
  my $self = shift;
  my $f = $self->formValidate(
    { name => 'actuator', enum => [0..$#mbn_types] },
    { name => 'sensor', enum => [0..$#mbn_types] },
  );
  return 404 if $f->{_err};

  my @buss = map $_->{label}, @{$self->dbAll('SELECT label FROM buss_config ORDER BY number')};
  my @mbuss = map $_->{label}, @{$self->dbAll('SELECT label FROM monitor_buss_config ORDER BY number')};
  my $src = $self->dbAll('SELECT number, label FROM src_config ORDER BY number');
  my $dest = $self->dbAll('SELECT number, label FROM dest_config ORDER BY number');
  my $dspcount = $self->dbRow('SELECT dsp_count() AS cnt')->{cnt};

  my $where = join ' OR ',
    $f->{sensor} ? "rcv_type = $f->{sensor}" : (),
    $f->{actuator} ? "xmt_type = $f->{actuator}" : ();
  $where = $where ? "WHERE $where" : '';
  my @func;
  for (@{$self->dbAll(
      'SELECT (func).type, (func).func, name, rcv_type, xmt_type FROM functions !s ORDER BY (func).func', $where)}) {
    push @{$func[$_->{type}]}, $_;
    delete $_->{type};
    $_->{name} =~ s{Buss \d+/(\d+)}{$buss[$1/2-1]}ieg;
  }

  # main select box
  div id => 'func_main'; Select;
   option value => -1, 'None';
   option value => 0, 'Module' if $func[0];
   option value => 1, 'Buss' if $func[1];
   option value => 2, 'Monitor buss' if $func[2];
   option value => 4, 'Global' if $func[4];
   option value => 5, 'Source' if $func[5];
   option value => 6, 'Destination' if $func[6];
  end;
  # module functions
  if($func[0]) {
    div id => 'func_0'; Select;
     option value => $_-1, $dspcount < $_/32 ? (class => 'off') : (), $_ for (1..128);
    end; Select;
     option value => $_->{func}, $_->{name} for @{$func[0]};
    end; end;
  }
  # buss functions
  if($func[1]) {
    div id => 'func_1'; Select;
     option value => $_, $buss[$_] for (0..$#buss);
    end; Select;
     option value => $_->{func}, $_->{name} for (@{$func[1]});
    end; end;
  }
  # monitor buss functions
  if($func[2]) {
    div id => 'func_2'; Select;
     option value => $_, $dspcount < ($_+1)/4 ? (class => 'off') : (), $mbuss[$_] for (0..$#mbuss);
    end; Select;
     option value => $_->{func}, $_->{name} for @{$func[2]};
    end; end;
  }
  # global functions
  if($func[4]) {
    div id => 'func_4'; Select;
     option value => $_->{func}, $_->{name} for @{$func[4]};
    end; end;
  }
  # source
  if($func[5]) {
    div id => 'func_5'; Select;
     option value => $_->{number}-1, $_->{label} for @$src;
    end; Select;
     option value => $_->{func}, $_->{name} for @{$func[5]};
    end; end;
  }
  # destination
  if($func[6]) {
    div id => 'func_6'; Select;
     option value => $_->{number}-1, $_->{label} for @$dest;
    end; Select;
     option value => $_->{func}, $_->{name} for @{$func[6]};
    end; end;
  }
}


sub setfunc {
  my $self = shift;

  my $f = $self->formValidate(
    { name => 'addr', regex => [qr/^[0-9a-f]{8}$/i] },
    { name => 'nr', template => 'int' },
    { name => 'function', regex => [qr/\d+,\d+,\d+/] },
    { name => 'sensor', template => 'int' },
    { name => 'actuator', template => 'int' },
  );
  return 404 if $f->{_err};
  my($f1, $f2, $f3) = split /,/, $f->{function};

  if($f1 == -1) {
    $self->dbExec('DELETE FROM node_config WHERE addr = ? AND object = ?', oct "0x$f->{addr}", $f->{nr});
  } else {
      $self->dbExec('UPDATE node_config SET func = (?, ?, ?) WHERE addr = ? AND object = ?', $f1, $f2, $f3, oct "0x$f->{addr}", $f->{nr})
    ||
      $self->dbExec('INSERT INTO node_config (addr, object, func) VALUES (?, ?, (?,?,?))', oct "0x$f->{addr}", $f->{nr}, $f1, $f2, $f3);
  }
  _funcname $self, $f->{addr}, $f->{nr}, $f1, $f2, $f3, $f->{sensor}, $f->{actuator},
    [ map $_->{label}, @{$self->dbAll('SELECT label FROM buss_config ORDER BY number')} ];
}


1;


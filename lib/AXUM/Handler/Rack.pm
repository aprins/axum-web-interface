
package AXUM::Handler::Rack;

use strict;
use warnings;
use YAWF ':html';


YAWF::register(
  qr{rack} => \&list,
  qr{surface} => \&listui,
  qr{(surface|rack)/([0-9a-f]{8})} => \&conf,
  qr{ajax/func} => \&funclist,
  qr{ajax/setfunc} => \&setfunc,
  qr{ajax/setdefault} => \&setdefault,
);


my @mbn_types = ('no data', 'unsigned int', 'signed int', 'state', 'octet string', 'float', 'bit string');


sub listui {
  my $self = shift;

  my $cards = $self->dbAll('SELECT a.addr, a.name, a.active, a.parent,
    (SELECT COUNT(*) FROM templates t WHERE t.man_id = (a.id).man AND t.prod_id = (a.id).prod AND t.firm_major = a.firm_major) AS objects,
    (SELECT number FROM templates t WHERE t.man_id = (a.id).man AND t.prod_id = (a.id).prod AND t.firm_major = a.firm_major AND t.description = \'Slot number\') AS slot_obj,
    (SELECT name FROM addresses b WHERE (b.id).man = (a.parent).man AND (b.id).prod = (a.parent).prod AND (b.id).id = (a.parent).id) AS parent_name,
    (SELECT COUNT(*) FROM node_config n WHERE a.addr = n.addr) AS config_cnt,
    (SELeCT COUNT(*) FROM defaults d WHERE a.addr = d.addr) AS default_cnt
    FROM slot_config s
    RIGHT JOIN addresses a ON a.addr = s.addr WHERE s.addr IS NULL AND ((a.parent).man != 1 OR (a.parent).prod != 12) AND NOT ((a.id).man=(a.parent).man AND (a.id).prod=(a.parent).prod AND (a.id).id=(a.parent).id)
    ORDER BY NULLIF((a.parent).man, 0), (a.parent).prod, (a.parent).id, NOT a.active, (a.id).man, (a.id).prod, (a.id).id');
  $self->htmlHeader(title => 'Surface configuration', page => 'surface');
  table;
   Tr; th colspan => 5, 'Surface configuration'; end;
   my $prev_parent='';
   for my $c (@$cards) {
     $c->{parent} =~ s/\((\d+),(\d+),(\d+)\)/sprintf($1?'%04X:%04X:%04X':'-', $1, $2, $3)/e;
     if($c->{parent} ne $prev_parent) {
       if ($prev_parent) {
         Tr class => 'empty'; th colspan => 5; end;
       }
       Tr; th colspan => 5, !$c->{parent_name} ? 'No parent' : "$c->{parent} ($c->{parent_name})"; end;
       Tr;
         th 'MambaNet Address';
         th 'Node name';
         th 'Default';
         th 'Config';
         th 'Settings';
       end;
       $prev_parent = $c->{parent};
     }

     Tr !$c->{active} ? (class => 'inactive') : ();
      td sprintf '%08X', $c->{addr};
      td $c->{name};
      td !$c->{default_cnt} ? (class => 'inactive') : (), $c->{default_cnt};
      td !$c->{config_cnt} ? (class => 'inactive') : (), $c->{config_cnt};
      td;
       if($c->{objects}) {
         a href => sprintf('/surface/%08x', $c->{addr}); lit 'configure &raquo;'; end;
       } else {
         a href => '#', class => 'off', 'no objects';
       }
      end;
     end;
   }
  end;
  $self->htmlFooter;
}


sub list {
  my $self = shift;

  my $cards = $self->dbAll('SELECT a.addr, a.name, s.slot_nr, s.input_ch_cnt, s.output_ch_cnt, a.active,
    (SELECT COUNT(*) FROM templates t WHERE t.man_id = (a.id).man AND t.prod_id = (a.id).prod AND t.firm_major = a.firm_major) AS objects,
    (SELECT COUNT(*) FROM node_config n WHERE a.addr = n.addr) AS config_cnt,
    (SELECT COUNT(*) FROM defaults d WHERE a.addr = d.addr) AS default_cnt
    FROM slot_config s JOIN addresses a ON a.addr = s.addr ORDER BY s.slot_nr');

  $self->htmlHeader(title => 'Rack configuration', page => 'rack');
  table;
   Tr; th colspan => 8, 'Rack configuration'; end;
   Tr;
    th 'Slot';
    th 'MambaNet Address';
    th 'Card name';
    th 'Inputs';
    th 'Outputs';
    th 'Default';
    th 'Config';
    th 'Settings';
   end;
   for my $c (@$cards) {
     Tr !$c->{active} ? (class => 'inactive') : ();
      th $c->{slot_nr};
      td sprintf '%08X', $c->{addr};
      td $c->{name};
      td !$c->{input_ch_cnt} ? (class => 'inactive') : (), $c->{input_ch_cnt};
      td !$c->{output_ch_cnt} ? (class => 'inactive') : (), $c->{output_ch_cnt};
      td !$c->{default_cnt} ? (class => 'inactive') : (), $c->{default_cnt};
      td !$c->{config_cnt} ? (class => 'inactive') : (), $c->{config_cnt};
      td;
       if($c->{objects}) {
         a href => sprintf('/rack/%08x', $c->{addr}); lit 'configure &raquo;'; end;
       } else {
         a href => '#', class => 'off', 'no objects';
       }
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

sub _default {
  my($addr, $row) = @_;

  return if !$row->{actuator_type};
  my $v = 0;                   # This regex doesn't correctly handle comma's or quotes in strings
  $v = $1 if defined $row->{actuator_def} && $row->{actuator_def} =~ /\(,*([^,]+),*\)/;
  $v = $1 if defined $row->{data} && $row->{data} =~ /\(,*([^,]+),*\)/;
  a href => '#', onclick => sprintf('return conf_text("setdefault", %d, "%s", %f, this)', $row->{number}, $addr, $1),
    !$row->{data} ? (class => 'off') : (), $1;
}


sub conf {
  my($self, $type, $addr) = @_;
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

  my $name = $self->dbRow($type eq 'rack'
    ? 'SELECT a.name, s.slot_nr FROM addresses a JOIN slot_config s ON s.addr = a.addr WHERE a.addr = ?'
    : 'SELECT a.name FROM addresses a WHERE a.addr = ?', oct "0x$addr");

  $self->htmlHeader(page => $type, section => $addr, title => "Object configuration for $addr");
  table;
   Tr; th colspan => 6, "Object configuration for $name->{name}".($type eq 'rack' ? " (slot $name->{slot_nr})" : ''); end;
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
      td; _default $addr, $o; end;
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


sub setdefault {
  my $self = shift;

  my $f = $self->formValidate(
    { name => 'item', template => 'int' },
    { name => 'field', regex => [qr/^[0-9a-f]{8}$/i] }, # = address
  );
  return if $f->{_err};
  my $v = $self->formValidate({name => $f->{field}});
  return if $v->{_err};
  $v = $v->{$f->{field}};

  my $obj = $self->dbRow('
      SELECT t.number, t.actuator_type, t.actuator_def, d.data
      FROM templates t
      JOIN addresses a ON (t.man_id = (a.id).man AND t.prod_id = (a.id).prod AND t.firm_major = a.firm_major)
      LEFT JOIN defaults d ON (d.addr = a.addr AND t.number = d.object)
      WHERE a.addr = ? AND t.number = ?',
    oct "0x$f->{field}", $f->{item}
  );
  return 404 if !$obj->{actuator_type};

  my $dat = $obj->{actuator_type} <= 3 ? "($v,,,)" :
            $obj->{actuator_type} == 4 ? qq|(,,,$v)| :
            $obj->{actuator_type} == 5 ? "(,$v,,)" : qq|(,,$v,)|;

  # TODO: compare value with actuator_def? check min-max?
  $self->dbExec(defined $obj->{data}
    ? 'UPDATE defaults SET data = ? WHERE addr = ? AND object = ?'
    : 'INSERT INTO defaults (data, addr, object) VALUES (?, ?, ?)',
    $dat, oct "0x$f->{field}", $f->{item}
  );

  $obj->{data} = $dat;
  _default $f->{field}, $obj;
}


1;


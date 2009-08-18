package AXUM::Handler::MambaNet;

use strict;
use warnings;
use YAWF ':html';


YAWF::register(
  qr{service/mambanet} => \&list,
  qr{service/predefined} => \&listpre,
  qr{ajax/mambanet} => \&ajax,
  qr{ajax/id_list} => \&id_list,
  qr{ajax/change_conf} => \&change_conf,
);


sub _col {
  my($n, $c) = @_;
  my $v = $c->{$n};

  if($n eq 'name' || $n eq 'engine_addr' || $n eq 'addr') {
    $v = sprintf '%08X', $v if $n eq 'engine_addr';
    $v = sprintf '%08X', $v if $n eq 'addr';
    (my $jsval = $v) =~ s/\\/\\\\/g;
    $v =~ s/"/\\"/g;
    a href => '#', onclick => sprintf('return conf_text("mambanet", "%s", "%s", "%s", this)', $c->{addr}, $n, $jsval),
      $n eq 'engine_addr' && $v eq '00000000' ? (class => 'off') : (), $v;
  }
  elsif ($n eq 'id') {
#    if (($c->{conf_change} != 0) and ($c->{default_cnt} or $c->{config_cnt})) {
    if ($c->{conf_change} and $c->{temp_cnt}) {
      (my $man = $c->{id})  =~ s/(\w{4}):(\w{4}):(\w{4})/$1/e;
      (my $prod = $c->{id}) =~ s/(\w{4}):(\w{4}):(\w{4})/$2/e;
      (my $uid = $c->{id})  =~ s/(\w{4}):(\w{4}):(\w{4})/$3/e;
      txt  $man.":".$prod.":";
      a href => '#', onclick => sprintf('return conf_id("%s", %d, %d, %d, this)', $c->{addr}, hex($man), hex($prod), $c->{firm_major}), $uid;
    }
    else {
      txt $c->{id};
    }
  }
}

sub list {
  my $self = shift;

  # if del, remove mambanet address
  # if refresh, update address table
  my $f = $self->formValidate(map +{name => $_, required => 0, template => 'int'}, 'del','refresh');
  if(!$f->{_err}) {
    $f->{del} ? ($self->dbExec('DELETE FROM addresses WHERE addr = ?', $f->{del})) : ();
    $f->{refresh} ? ($self->dbExec('UPDATE addresses SET refresh = TRUE WHERE addr = ?', $f->{refresh})) : ();
    ($f->{del} or $f->{refresh}) ? (return $self->resRedirect('/service/mambanet', 'temp')) : ();
  }

  my $cards = $self->dbAll('SELECT a.addr, a.id, a.name, a.active, a.engine_addr, a.parent, a.firm_major, b.name AS parent_name,
    (SELECT COUNT(*) FROM node_config n WHERE a.addr = n.addr) AS config_cnt,
    (SELECT COUNT(*) FROM defaults d WHERE a.addr = d.addr) AS default_cnt,
    (SELECT COUNT(*) FROM addresses b WHERE (b.id).man = (a.id).man AND (b.id).prod = (a.id).prod AND b.firm_major = a.firm_major AND b.active AND NOT a.active) AS conf_change,
    (SELECT COUNT(*) FROM templates t WHERE (a.id).man = t.man_id AND (a.id).prod = t.prod_id AND a.firm_major = t.firm_major) AS temp_cnt
    FROM addresses a
    LEFT JOIN addresses b ON (b.id).man = (a.parent).man AND (b.id).prod = (a.parent).prod AND (b.id).id = (a.parent).id
    ORDER BY a.addr');

  $self->htmlHeader(title => 'MambaNet configuration', page => 'service', section => 'mambanet');
  table;
   Tr; th colspan => 9, 'MambaNet configuration'; end;
   Tr;
    th 'Address';
    th 'Unique ID';
    th 'Node name';
    th 'Engine';
    th 'Parent';
    th 'Default';
    th 'Config';
    th 'Objects';
    th '';
   end;
   for my $c (@$cards) {
     $c->{$_} =~ s/\((\d+),(\d+),(\d+)\)/sprintf($1?'%04X:%04X:%04X':'-', $1, $2, $3)/e
       for ('parent', 'id');
     Tr !$c->{active} ? (class => 'inactive') : ();
      td; _col 'addr', $c; end;
      td style => "white-space: nowrap"; _col 'id', $c; end;
      td; _col 'name', $c; end;
      td; _col 'engine_addr', $c; end;
      td $c->{parent};
      td !$c->{default_cnt} ? (class => 'inactive') : (), $c->{default_cnt};
      td !$c->{config_cnt} ? (class => 'inactive') : (), $c->{config_cnt};
      td !$c->{temp_cnt} ? (class => 'inactive') : (), $c->{temp_cnt};
      td valign => 'middle';
       if (!$c->{active}) {
         a href => '/service/mambanet?del='.$c->{addr}, title => 'Delete';
          img src => '/images/delete.png', alt => 'delete';
         end;
       }
       else {
         a href => '/service/mambanet?refresh='.$c->{addr}, title => 'Refresh';
           img src => '/images/refresh.png', alt => 'refresh';
         end;
       }
      end;
     end;
   }
  end;
  $self->htmlFooter;
}

sub listpre {
  my $self = shift;

  # if del, remove mambanet address
  # if refresh, update address table
  my $f = $self->formValidate(
    { name => 'del', required => 0, maxlength => 32, minlength => 1 },
    { name => 'man', required => 0, template => 'int' },
    { name => 'prod', required => 0, template => 'int' },
    { name => 'firm', required => 0, template => 'int' },
  );

  if(!$f->{_err}) {
    $f->{del} ? ($self->dbExec('DELETE FROM predefined_node_config WHERE cfg_name = ? AND man_id = ? AND prod_id = ? AND firm_major = ?', $f->{del}, $f->{man}, $f->{prod}, $f->{firm})) : ();
    $f->{del} ? (return $self->resRedirect('/service/predefined', 'temp')) : ();
  }

  my $pre_cfg = $self->dbAll("SELECT p.cfg_name, p.man_id, p.prod_id, p.firm_major, COUNT(*) AS cnt
                              FROM predefined_node_config p
                              GROUP BY p.cfg_name, p.man_id, p.prod_id, p.firm_major
                              ORDER BY p.man_id, p.prod_id, p.firm_major");

  $self->htmlHeader(title => 'MambaNet predefined configurations', page => 'service', section => 'predefined');
  table;
   Tr; th colspan => 6, 'MambaNet predefined configuration'; end;
   Tr;
    th 'ManID';
    th 'ProdID';
    th 'Major';
    th 'Name';
    th 'count';
    th '';
   end;
   for my $p (@$pre_cfg) {
     Tr;
      td sprintf("%04X", $p->{man_id});
      td sprintf("%04X", $p->{prod_id});
      td $p->{firm_major};
      td $p->{cfg_name};
      td $p->{cnt};
      td;
       $p->{cfg_name} =~ s/([^A-Za-z0-9])/sprintf("%%%02X", ord($1))/seg;
       a href => '/service/predefined?del='.$p->{cfg_name}.";man=".$p->{man_id}.";prod=".$p->{prod_id}.";firm=".$p->{firm_major}, title => 'Delete';
        img src => '/images/delete.png', alt => 'delete';
       end;
      end;
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
    { name => 'name', required => 0, maxlength => 32, minlength => 1 },
    { name => 'engine_addr', required => 0, regex => [qr/^[0-9a-f]{8}$/i] },
    { name => 'addr', required => 0, regex => [qr/^[0-9a-f]{8}$/i] },
  );
  return 404 if $f->{_err};

  my %set;
  defined $f->{$_} and ($set{"$_ = ?"} = $f->{$_})
    for(qw|name|);
  $set{"engine_addr = ?"} = oct "0x$f->{engine_addr}" if defined $f->{engine_addr};
  $set{"addr = ?"} = oct "0x$f->{addr}" if defined $f->{addr};

  $self->dbExec('UPDATE addresses !H WHERE addr = ?', \%set, $f->{item}) if keys %set;

  _col $f->{field}, { addr => $f->{item}, $f->{field} => oct "0x$f->{engine_addr}"} if defined $f->{engine_addr};
  _col $f->{field}, { addr => $f->{item}, $f->{field} => oct "0x$f->{addr}"} if defined $f->{addr};
  _col $f->{field}, { addr => $f->{item}, $f->{field} => $f->{$f->{field}} } if not defined $f->{engine_addr} and not defined $f->{addr};
}

sub id_list {
  my $self = shift;
  my $f = $self->formValidate(
    { name => 'man', enum => [1..65535] },
    { name => 'prod', enum => [1..65535] },
    { name => 'firm_major', enum => [0..255] },
  );
  return 404 if $f->{_err};

  my @ids = @{$self->dbAll('SELECT ((id).id) AS uid, id, name FROM addresses WHERE (id).man = ? AND (id).prod = ? AND firm_major = ? AND active', $f->{man}, $f->{prod}, $f->{firm_major})};

  # main select box
  div id => 'id_main'; Select;
   for my $id (@ids) {
     (my $id_text = $id->{id}) =~ s/\((\d+),(\d+),(\d+)\)/sprintf(" (%04X:%04X:%04X)", $1, $2, $3)/e;
     option value => $id->{uid}, $id->{name}.$id_text;
   }
  end;
}

sub change_conf {
  my $self = shift;

  my $f = $self->formValidate(
    { name => 'addr', template => 'int' },
    { name => 'man', template => 'int' },
    { name => 'prod', template => 'int' },
    { name => 'id', template => 'int' },
    { name => 'firm_major', template => 'int' },
  );
  return 404 if $f->{_err};

  $self->dbExec("UPDATE addresses SET id.id = ?, refresh = TRUE WHERE addr = ? AND (id).man = ? AND (id).prod = ? AND firm_major = ?", $f->{id}, $f->{addr}, $f->{man}, $f->{prod}, $f->{firm_major});

  txt 'Wait for refresh';
}


1;


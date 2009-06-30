package AXUM::Handler::MambaNet;

use strict;
use warnings;
use YAWF ':html';


YAWF::register(
  qr{mambanet} => \&list,
  qr{ajax/mambanet} => \&ajax,
  qr{ajax/id_list} => \&id_list,
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
    my $first_id = $v;
    my $unique_id = $v;
    $first_id =~ s/(\w{4}):(\w{4}):(\w{4})/sprintf("%04X:%04X:", hex($1), hex($2))/i;
    $unique_id =~ s/(\w{4}):(\w{4}):(\w{4})/sprintf("%04X", hex($3))/i;
    lit $first_id;
    a href => '#', onclick => sprintf('return conf_id(%d,%d,%d,this)', 0, hex($1), hex($2)), $unique_id;
  }
}

sub _id_link {
  my($self, $addr, $id) = @_;
  (my $man = $id)  =~ s/(\w{4}):(\w{4}):(\w{4})/$1/e;
  (my $prod = $id) =~ s/(\w{4}):(\w{4}):(\w{4})/$2/e;
  (my $uid = $id)  =~ s/(\w{4}):(\w{4}):(\w{4})/$3/e;
   txt  $man.":".$prod.":";
   a href => '#', onclick => sprintf('return conf_id("%s", %d, %d, this)', $addr, hex($man), hex($prod));
    txt $uid;
   end;
}

sub list {
  my $self = shift;

  # if del, remove mambanet address 
  my $f = $self->formValidate({name => 'del', template => 'int'});
  if(!$f->{_err}) {
    $self->dbExec('DELETE FROM addresses WHERE addr = ?', $f->{del});
    return $self->resRedirect('/mambanet');
  }

  my $cards = $self->dbAll('SELECT a.addr, a.id, a.name, a.active, a.engine_addr, a.parent, b.name AS parent_name,
    (SELECT COUNT(*) FROM node_config n WHERE a.addr = n.addr) AS config_cnt,
    (SELECT COUNT(*) FROM defaults d WHERE a.addr = d.addr) AS default_cnt,
    (SELECT COUNT(*) FROM addresses b WHERE (b.id).man = (a.id).man AND (b.id).prod = (a.id).prod AND NOT b.active AND a.active) AS conf_change
    FROM addresses a
    LEFT JOIN addresses b ON (b.id).man = (a.parent).man AND (b.id).prod = (a.parent).prod AND (b.id).id = (a.parent).id
    ORDER BY a.addr');

  $self->htmlHeader(title => 'MambaNet configuration', page => 'mambanet');
  table;
   Tr; th colspan => 8, 'MambaNet configuration'; end;
   Tr;
    th 'Address';
    th 'Unique ID';
    th 'Node name';
    th 'Engine';
    th 'Parent';
    th 'Default';
    th 'Config';
    th '';
   end;
   for my $c (@$cards) {
     $c->{$_} =~ s/\((\d+),(\d+),(\d+)\)/sprintf($1?'%04X:%04X:%04X':'-', $1, $2, $3)/e
       for ('parent', 'id');
     Tr !$c->{active} ? (class => 'inactive') : ();
      td; _col 'addr', $c; end;
      if (($c->{conf_change} != 0) and ($c->{default_cnt} or $c->{config_cnt})) {
        td style => "white-space: nowrap";
         _id_link $self, sprintf("%08X", $c->{addr}), $c->{id};
        end;
      }
      else {
        td $c->{id};
      }
      td; _col 'name', $c; end;
      td; _col 'engine_addr', $c; end;
      td $c->{parent};
      td !$c->{default_cnt} ? (class => 'inactive') : (), $c->{default_cnt};
      td !$c->{config_cnt} ? (class => 'inactive') : (), $c->{config_cnt};
      td;
       if (!$c->{active}) {
         a href => '/mambanet?del='.$c->{addr}, title => 'Delete';
          img src => '/images/delete.png', alt => 'delete';
         end;
       }
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
  );
  return 404 if $f->{_err};

  my @ids = @{$self->dbAll('SELECT ((id).id) AS uid, id, name FROM addresses WHERE (id).man = ? AND (id).prod = ? AND NOT active', $f->{man}, $f->{prod})};

  # main select box
  div id => 'id_main'; Select;

   for my $id (@ids) {
     (my $id_text = $id->{id}) =~ s/\((\d+),(\d+),(\d+)\)/sprintf(" (%04X:%04X:%04X)", $1, $2, $3)/e;
     option value => $id->{uid}, $id->{name}.$id_text;
   }
  end;
}

1;


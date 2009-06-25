
package AXUM::Handler::MambaNet;

use strict;
use warnings;
use YAWF ':html';


YAWF::register(
  qr{mambanet} => \&list,
);


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
    (SELECT COUNT(*) FROM defaults d WHERE a.addr = d.addr) AS default_cnt
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
      td sprintf '%08X', $c->{addr};
      td $c->{id};
      td $c->{name};
      td sprintf '%08X', $c->{engine_addr};
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


1;



package AXUM::Handler::Main;

use strict;
use warnings;
use YAWF ':html';

YAWF::register(
  qr{service} => \&service,
  qr{service/functions} => \&functions,
  qr{ajax/service} => \&ajax,
);

my @mbn_types = ('no data', 'unsigned int', 'signed int', 'state', 'octet string', 'float', 'bit string');
my @func_types = ('Module', 'Buss', 'Monitor buss', 'None', 'Global', 'Source', 'Destination');

sub service {
  my $self = shift;

  $self->htmlHeader(title => $self->OEMFullProductName().' service pages', page => 'service');
  table;
   Tr; th colspan => 2, $self->OEMFullProductName().' service'; end;
   Tr; th 1; td; a href => '/service/mambanet', 'MambaNet node overview'; end; end;
   Tr; th 2; td; a href => '#', onclick => 'return msg_box("Are you sure to remove all current sources and generate new sources?", "/source/generate")', 'Generate sources'; end; end;
   Tr; th 3; td; a href => '#', onclick => 'return msg_box("Are you sure to remove all current destination and generate new destinations?", "/dest/generate")', 'Generate destinations'; end; end;
   Tr; th 4; td; a href => '/service/predefined', 'Stored configurations'; end; end;
   Tr; th 5; td; a href => '/service/functions', 'Engine functions'; end; end;
  end;
  $self->htmlFooter;
}

sub _col {
  my($n, $d, $lst) = @_;
  my $v = $d->{$n};

  if($n eq 'pos') {
    a href => '#', onclick => sprintf('return conf_select("service", "%d|%d|%d|%d", "%s", "%s", this, "func_list", "Place before ", "Move")', $d->{rcv_type}, $d->{xmt_type}, $d->{type}, $d->{func}, $n, "$d->{pos}"), $d->{pos};
  }
}

sub functions {
  my $self = shift;

  my $src = $self->dbAll(q|SELECT pos, (func).type AS type, (func).func AS func, name, rcv_type, xmt_type FROM functions ORDER BY pos|);

  $self->htmlHeader(title => $self->OEMFullProductName().' service pages', page => 'service', section => 'functions');

  # create list of functions for javascript
  div id => 'func_list', class => 'hidden';
   Select;
   my $max_pos;
    $max_pos = 0;
    for (@$src) {
      option value => "$_->{pos}", $func_types[$_->{type}]." - ".$_->{name};
      $max_pos = $_->{pos} if ($_->{pos} > $max_pos);
    }
    option value => $max_pos+1, "last";
   end;
  end;

  table;
   Tr; th colspan => 5, $self->OEMFullProductName().' functions'; end;
   Tr; th 'pos'; th 'type'; th 'function'; th 'rcv'; th 'xmt'; end;
   for my $s (@$src) {
     Tr;
      th; _col 'pos', $s; end;
      td $func_types[$s->{type}];
      td $s->{name};
      td $mbn_types[$s->{rcv_type}];
      td $mbn_types[$s->{xmt_type}];
     end;
   }
  end;
  $self->htmlFooter;
}

sub ajax {
  my $self = shift;

  my $f = $self->formValidate(
    { name => 'field', template => 'asciiprint' },
    { name => 'item', template => 'asciiprint' },
    { name => 'pos', required => 0, template => 'int' },
  );
  return 404 if $f->{_err};

  #if field returned is 'pos', the positions of other rows may change...
  if($f->{field} eq 'pos') {
    $f->{item} =~ /(\d+)\|(\d+)\|(\d+)\|(\d+)/;
    my $rcv_type = $1;
    my $xmt_type = $2;
    my $type = $3;
    my $func = $4;

    $self->dbExec("UPDATE functions SET pos =
                   CASE
                    WHEN pos < $f->{pos} AND NOT (rcv_type = $rcv_type AND xmt_type = $xmt_type AND (func).type = $type AND (func).func = $func) THEN pos
                    WHEN pos >= $f->{pos} AND NOT (rcv_type = $rcv_type AND xmt_type = $xmt_type AND (func).type = $type AND (func).func = $func) THEN pos+1
                    WHEN rcv_type = $rcv_type AND xmt_type = $xmt_type AND (func).type = $type AND (func).func = $func THEN $f->{pos}
                    ELSE 9999
                   END;");
    $self->dbExec("SELECT functions_renumber();");
    txt 'Wait for reload';
  }
}


1;


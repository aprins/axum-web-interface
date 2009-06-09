
package AXUM::Handler::Module;

use strict;
use warnings;
use YAWF ':html';


YAWF::register(
  qr{module} => \&overview,
  qr{module/([1-9][0-9]*)} => \&conf,
  qr{ajax/module} => \&ajax,
);


sub overview {
  my $self = shift;

  my $p = $self->formValidate({name => 'p', required => 0, default => 1, enum => [1..4]});
  return 404 if $p->{_err};
  $p = $p->{p};

  my $mod = $self->dbAll(q|
    SELECT m.number, a.label AS label_a, a.active AS active_a, b.label AS label_b, b.active AS active_b, mod_level, mod_on_off
    FROM module_config m
    LEFT JOIN matrix_sources a ON a.number = m.source_a
    LEFT JOIN matrix_sources b ON b.number = m.source_b
    WHERE m.number >= ? AND m.number <= ?
    ORDER BY m.number|,
    $p*32-31, $p*32
  );
  my $dspcount = $self->dbRow('SELECT dsp_count() AS cnt')->{cnt};

  $self->htmlHeader(page => 'module', title => 'Module overview');
  table;
   Tr;
    th colspan => 9;
     p class => 'navigate';
      txt 'Page: ';
      a href => "?p=$_", $p == $_ ? (class => 'sel') : (), $_
        for (1..4);
     end;
     txt 'Module overview';
    end;
   end;

   for my $m (0..$#$mod/8) {
     my @m = ($m*8)..($m*8+7);
     Tr $p > $dspcount ? (class => 'inactive') : ();
      th '';
      th sprintf 'Module %d', $mod->[$_]{number} for (@m);
     end;
     for my $src ('a', 'b') {
       Tr $p > $dspcount ? (class => 'inactive') : ();
        th "Source \u$src";
        for (@m) {
          td;
           a href => "/module/$mod->[$_]{number}",
            !$mod->[$_]{"active_$src"} || !$mod->[$_]{"label_$src"} ? (class => 'off') : (), $mod->[$_]{"label_$src"}||'none';
          end;
        }
       end;
     }
     Tr $p > $dspcount ? (class => 'inactive') : ();
      th 'Level';
      for (@m) {
        td;
         a href => "/module/$mod->[$_]{number}", $mod->[$_]{mod_level}==-140 ? (class => 'off') : (),
           sprintf '%.1f dB', $mod->[$_]{mod_level};
        end;
      }
     end;
     Tr $p > $dspcount ? (class => 'inactive') : ();
      th 'State';
      for (@m) {
        td;
         a href => "/module/$mod->[$_]{number}",
           $mod->[$_]{mod_on_off} ? 'on' : (class => 'off', 'off');
        end;
      }
     end;
     Tr $p > $dspcount ? (class => 'inactive') : ();
      td colspan => 9, style => 'background: none', '';
     end;
   }
  end;
  $self->htmlFooter;
}


sub _col {
  my($n, $d, $lst) = @_;
  my $v = $d->{$n};

  if($n eq 'source_a' || $n eq 'source_b' || $n eq 'insert_source') {
    a href => '#', onclick => sprintf('return conf_select("module", %d, "%s", %d, this, "matrix_sources")', $d->{number}, $n, $v),
      !$v || !$lst->[$v-1]{active} ? (class => 'off') : (), $v ? $lst->[$v-1]{label} : 'none';
  }
  if($n eq 'gain' || $n eq 'mod_level') {
    a href => '#', onclick => sprintf('return conf_level("module", %d, "%s", %f, this)', $d->{number}, $n, $v),
      $v == 0 ? (class => 'off') : (), sprintf '%.1f dB', $v;
  }
  if($n =~ /.+_on_off_[ab]/) {
    a href => '#', onclick => sprintf('return conf_set("module", %d, "%s", "%s", this)', $d->{number}, $n, $v?0:1),
      $v ? 'yes' : (class => 'off', 'no');
  }
  if($n eq 'mod_on_off') {
    a href => '#', onclick => sprintf('return conf_set("module", %d, "%s", "%s", this)', $d->{number}, $n, $v?0:1),
      $v ? 'on' : (class => 'off', 'off');
  }
  if($n eq 'lc_frequency') {
    a href => '#', onclick => sprintf('return conf_freq("module", %d, "lc_frequency", %d, this)', $d->{number}, $v),
      sprintf '%d Hz', $v;
  }
  if($n eq 'dyn_amount') {
    a href => '#', onclick => sprintf('return conf_proc("module", %d, "dyn_amount", %d, this)', $d->{number}, $v),
      sprintf '%d%%', $v;
  }
}


sub conf {
  my($self, $nr) = @_;

  my $mod = $self->dbRow(q|
    SELECT number, source_a, source_b, insert_source, insert_on_off_a, insert_on_off_b,
      gain, lc_frequency, lc_on_off_a, lc_on_off_b, eq_on_off_a, eq_on_off_b,
      dyn_amount, dyn_on_off_a, dyn_on_off_b, mod_level, mod_on_off
    FROM module_config
    WHERE number = ?|,
    $nr
  );
  return 404 if !$mod->{number};

  my $lst = $self->dbAll(q|SELECT number, label, type, active FROM matrix_sources ORDER BY number|);

  $self->htmlHeader(page => 'module', section => $nr, title => "Module $nr configuration");
  $self->htmlSourceList($lst, 'matrix_sources');
  table;
   Tr; th colspan => 4, "Configuration for module $nr"; end;
   Tr; th 'Source A'; td colspan => 3; _col 'source_a', $mod, $lst; end; end;
   Tr; th 'Source B'; td colspan => 3; _col 'source_b', $mod, $lst; end; end;
   Tr; th 'Gain';     td colspan => 3; _col 'gain', $mod; end; end;
   Tr; td colspan => 4, style => 'background: none', ''; end;
   Tr;
    th '';
    th 'A';
    th 'B';
    th '';
   end;
   Tr; th 'Low cut';
    td; _col 'lc_on_off_a', $mod; end;
    td; _col 'lc_on_off_b', $mod; end;
    td; _col 'lc_frequency', $mod; end;
   end;
   Tr; th 'Insert';
    td; _col 'insert_on_off_a', $mod; end;
    td; _col 'insert_on_off_b', $mod; end;
    td; _col 'insert_source', $mod, $lst; end;
   end;
   Tr; th 'EQ';
    td; _col 'eq_on_off_a', $mod; end;
    td; _col 'eq_on_off_b', $mod; end;
    td;
     a href => "/module/$nr/eq"; lit 'EQ settings &raquo;'; end;
    end;
   end;
   Tr; th 'Dynamics';
    td; _col 'dyn_on_off_a', $mod; end;
    td; _col 'dyn_on_off_b', $mod; end;
    td; _col 'dyn_amount', $mod; end;
   end;
   Tr; td colspan => 4, style => 'background: none', ''; end;
   Tr; th colspan => 4, 'Module'; end;
   Tr; th 'Level'; td colspan => 3; _col 'mod_level', $mod; end; end;
   Tr; th 'State'; td colspan => 3; _col 'mod_on_off', $mod; end; end;
  end;
  $self->htmlFooter;
}


sub ajax {
  my $self = shift;

  my @booleans = qw|lc_on_off_a lc_on_off_b insert_on_off_a insert_on_off_b
    eq_on_off_a eq_on_off_b dyn_on_off_a dyn_on_off_b mod_on_off|;

  my $f = $self->formValidate(
    { name => 'field', template => 'asciiprint' },
    { name => 'item', template => 'int' },
    { name => 'source_a', required => 0, template => 'int' },
    { name => 'source_b', required => 0, template => 'int' },
    { name => 'insert_source', required => 0, template => 'int' },
    { name => 'mod_level', required => 0, regex => [ qr/-?[0-9]*(\.[0-9]+)?/, 0 ] },
    { name => 'gain', required => 0, regex => [ qr/-?[0-9]*(\.[0-9]+)?/, 0 ] },
    { name => 'lc_frequency', required => 0, template => 'int' },
    { name => 'dyn_amount', required => 0, template => 'int' },
    (map +{ name => $_, required => 0, enum => [0,1] }, @booleans),
  );
  return 404 if $f->{_err};

  my %set;
  defined $f->{$_} and ($set{"$_ = ?"} = $f->{$_})
    for(@booleans, qw|source_a source_b mod_level lc_frequency gain dyn_amount|);

  $self->dbExec('UPDATE module_config !H WHERE number = ?', \%set, $f->{item}) if keys %set;
  _col $f->{field}, { number => $f->{item}, $f->{field} => $f->{$f->{field}} },
    $f->{field} =~ /source/ ? $self->dbAll(q|SELECT number, label, active FROM matrix_sources ORDER BY number|) : ();
}


1;


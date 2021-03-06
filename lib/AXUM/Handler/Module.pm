
package AXUM::Handler::Module;

use strict;
use warnings;
use YAWF ':html';


YAWF::register(
  qr{module} => \&overview,
  qr{module/([1-9][0-9]*)} => \&conf,
  qr{ajax/module} => \&ajax,
  qr{ajax/module/([1-9][0-9]*)/eq} => \&eqajax,
);

my @phase_types = ('Normal', 'Left', 'Right', 'Both');
my @mono_types = ('Stereo', 'Left', 'Right', 'Mono');

sub overview {
  my $self = shift;

  my $p = $self->formValidate({name => 'p', required => 0, default => 1, enum => [1..4]});
  return 404 if $p->{_err};
  $p = $p->{p};

  my $mod = $self->dbAll(q|
    SELECT m.number,
      a.label AS label_a, a.active AS active_a, b.label AS label_b, b.active AS active_b,
      c.label AS label_c, c.active AS active_c, d.label AS label_d, d.active AS active_d,
      insert_on_off, lc_on_off, eq_on_off, dyn_on_off
    FROM module_config m
    LEFT JOIN matrix_sources a ON a.number = m.source_a
    LEFT JOIN matrix_sources b ON b.number = m.source_b
    LEFT JOIN matrix_sources c ON c.number = m.source_c
    LEFT JOIN matrix_sources d ON d.number = m.source_d
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
     for my $src ('a', 'b', 'c', 'd') {
       Tr $p > $dspcount ? (class => 'inactive') : ();
        th "Source \u$src";
        for (@m) {
          td;
           a href => "/module/$mod->[$_]{number}",
            !$mod->[$_]{"active_$src"} || !$mod->[$_]{"label_$src"} || ($mod->[$_]{"label_$src"} eq 'none') ? (class => 'off') : (), $mod->[$_]{"label_$src"}||'none';
          end;
        }
       end;
     }
     Tr $p > $dspcount ? (class => 'inactive') : ();
      th 'Processing';
      for (@m) {
        my $active = ($mod->[$_]{lc_on_off} or
                      $mod->[$_]{insert_on_off} or
                      $mod->[$_]{eq_on_off} or
                      $mod->[$_]{dyn_on_off});

         td;
          a href => "/module/$mod->[$_]{number}", $active ? () : (class => 'off');
           txt $mod->[$_]{lc_on_off} ? ('LC ') : ();
           txt $mod->[$_]{insert_on_off} ? ('Ins ') : ();
           txt $mod->[$_]{eq_on_off} ? ('EQ ') : ();
           txt $mod->[$_]{dyn_on_off} ? ('Dyn ') : ();
           txt (($mod->[$_]{lc_on_off} or
                $mod->[$_]{insert_on_off} or
                $mod->[$_]{eq_on_off} or
                $mod->[$_]{dyn_on_off}) ? () : ('none'));

          end;
         end;
      }
     end;
     Tr $p > $dspcount ? (class => 'inactive') : ();
      th 'Routing';
      for (@m) {
        td;
         a href => "/module/$mod->[$_]{number}/route"; lit 'Routing &raquo;'; end;
        end;
      }
     end;
     Tr;
      td colspan => 9, style => 'background: none', '';
     end;
   }
  end;
  $self->htmlFooter;
}


sub _col {
  my($n, $d, $lst) = @_;
  my $v = $d->{$n};

  if($n eq 'source_a' || $n eq 'source_b' || $n eq 'source_c' || $n eq 'source_d' || $n eq 'insert_source') {
    $v = 0 if (!$lst->[$v]);
    a href => '#', onclick => sprintf('return conf_select("module", %d, "%s", %d, this, "matrix_sources")', $d->{number}, $n, $v),
      !$v || !$lst->[$v]{active} ? (class => 'off') : (), $v ? $lst->[$v]{label} : 'none';
  }
  if($n eq 'gain' || $n eq 'mod_level') {
    a href => '#', onclick => sprintf('return conf_level("module", %d, "%s", %f, this)', $d->{number}, $n, $v),
      $v == 0 ? (class => 'off') : (), sprintf '%.1f dB', $v;
  }
  if($n =~ /.+_on_off/) {
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
  if($n eq 'phase') {
    a href => '#', onclick => sprintf('return conf_select("module", %d, "%s", %d, this, "phase_list")', $d->{number}, $n, $v),
      $v == 3 ? (class => 'off') : (), $phase_types[$v];
  }
  if($n eq 'mono') {
    a href => '#', onclick => sprintf('return conf_select("module", %d, "%s", %d, this, "mono_list")', $d->{number}, $n, $v),
      $v == 3 ? (class => 'off') : (), $mono_types[$v];
  }
}


sub _eqtable {
  my $d = shift;

  my @eq_types = ('Off', 'HPF', 'Low shelf', 'Peaking', 'High shelf', 'LPF', 'BPF', 'Notch');

  table;
   Tr; th 'Band'; th 'Range'; th 'Level'; th 'Frequency'; th 'Bandwidth'; th 'Type'; end;
   for my $i (1..6) {
     Tr;
      th $i;
      td;
       input type => 'text', class => 'text', size => 4, name => "eq_band_${i}_range",
         value => $d->{"eq_band_${i}_range"};
       txt ' dB';
      end;
      td;
       input type => 'text', class => 'text', size => 4, name => "eq_band_${i}_level",
         value => $d->{"eq_band_${i}_level"};
       txt ' dB';
      end;
      td;
       input type => 'text', class => 'text', size => 7, name => "eq_band_${i}_freq",
         value => $d->{"eq_band_${i}_freq"};
       txt ' Hz';
      end;
      td;
       txt 'Q = ';
       input type => 'text', class => 'text', size => 4, name => "eq_band_${i}_bw",
         value => sprintf '%.1f', $d->{"eq_band_${i}_bw"};
      end;
      td;
       Select style => 'width: 100px', name => "eq_band_${i}_type";
        option value => $_, $_ == $d->{"eq_band_${i}_type"} ? (selected => 'selected') : (),
          $eq_types[$_] for (0..$#eq_types);
       end;
      end;
     end;
   }
   Tr;
    td '';
    td '0 - 18';
    td '-Range - +Range';
    td '20 - 20000';
    td '0.1 - 10';
    td;
     input type => 'submit', style => 'float: right', class => 'button', value => 'Save';
    end;
   end;
  end;
}


sub conf {
  my($self, $nr) = @_;

  my $mod = $self->dbRow(q|
    SELECT number, source_a, source_b, source_c, source_d, insert_source, insert_on_off,
      gain, lc_frequency, lc_on_off, phase, phase_on_off, mono, mono_on_off, eq_on_off, dyn_amount, dyn_on_off,
      mod_level, mod_on_off,
      eq_band_1_range, eq_band_1_level,  eq_band_1_freq, eq_band_1_bw, eq_band_1_type,
      eq_band_2_range, eq_band_2_level, eq_band_2_freq, eq_band_2_bw, eq_band_2_type,
      eq_band_3_range, eq_band_3_level, eq_band_3_freq, eq_band_3_bw, eq_band_3_type,
      eq_band_4_range, eq_band_4_level, eq_band_4_freq, eq_band_4_bw, eq_band_4_type,
      eq_band_5_range, eq_band_5_level, eq_band_5_freq, eq_band_5_bw, eq_band_5_type,
      eq_band_6_range, eq_band_6_level, eq_band_6_freq, eq_band_6_bw, eq_band_6_type
    FROM module_config
    WHERE number = ?|,
    $nr
  );
  return 404 if !$mod->{number};

  my $pos_lst = $self->dbAll(q|SELECT number, label, type, active FROM matrix_sources ORDER BY pos|);
  my $src_lst = $self->dbAll(q|SELECT number, label, type, active FROM matrix_sources ORDER BY number|);

  $self->htmlHeader(page => 'module', section => $nr, title => "Module $nr configuration");
  $self->htmlSourceList($pos_lst, 'matrix_sources');
  div id => 'eq_table_container', class => 'hidden';
   _eqtable($mod);
  end;
  div id => 'phase_list', class => 'hidden';
   Select;
    option value => $_, $phase_types[$_]
      for (0..3);
   end;
  end;
  div id => 'mono_list', class => 'hidden';
   Select;
    option value => $_, $mono_types[$_]
      for (0..3);
   end;
  end;
  table;
   Tr; th colspan => 4, "Configuration for module $nr"; end;
   Tr; th 'Source A'; td colspan => 3; _col 'source_a', $mod, $src_lst; end; end;
   Tr; th 'Source B'; td colspan => 3; _col 'source_b', $mod, $src_lst; end; end;
   Tr; th 'Source C'; td colspan => 3; _col 'source_c', $mod, $src_lst; end; end;
   Tr; th 'Source D'; td colspan => 3; _col 'source_d', $mod, $src_lst; end; end;
   Tr; td colspan => 4, style => 'background: none', ''; end;
   Tr;
    th '';
    th 'State';
    th 'Value';
   end;
   Tr; th 'Digital gain';
    td '-';
    td; _col 'gain', $mod; end;
   end;
   Tr; th 'Low cut';
    td; _col 'lc_on_off', $mod; end;
    td; _col 'lc_frequency', $mod; end;
   end;
   Tr; th 'Insert';
    td; _col 'insert_on_off', $mod; end;
    td; _col 'insert_source', $mod, $src_lst; end;
   end;
   Tr; th 'Phase';
    td; _col 'phase_on_off', $mod; end;
    td; _col 'phase', $mod; end;
   end;
   Tr; th 'Mono';
    td; _col 'mono_on_off', $mod; end;
    td; _col 'mono', $mod; end;
   end;
   Tr; th 'EQ';
    td; _col 'eq_on_off', $mod; end;
    td;
     a href => "#", onclick => "return conf_eq(\"module\", this, $nr)"; lit 'EQ settings &raquo;'; end;
    end;
   end;
   Tr; th 'Dynamics';
    td; _col 'dyn_on_off', $mod; end;
    td; _col 'dyn_amount', $mod; end;
   end;
   Tr; td colspan => 4, style => 'background: none', ''; end;
   Tr; th colspan => 4, 'Module at startup'; end;
   Tr; th 'Level'; td colspan => 3; _col 'mod_level', $mod; end; end;
   Tr; th 'State'; td colspan => 3; _col 'mod_on_off', $mod; end; end;
  end;
  $self->htmlFooter;
}


sub ajax {
  my $self = shift;

  my @booleans = qw|lc_on_off insert_on_off phase_on_off mono_on_off eq_on_off dyn_on_off mod_on_off|;

  my $f = $self->formValidate(
    { name => 'field', template => 'asciiprint' },
    { name => 'item', template => 'int' },
    { name => 'source_a', required => 0, template => 'int' },
    { name => 'source_b', required => 0, template => 'int' },
    { name => 'source_c', required => 0, template => 'int' },
    { name => 'source_d', required => 0, template => 'int' },
    { name => 'insert_source', required => 0, template => 'int' },
    { name => 'mod_level', required => 0, regex => [ qr/-?[0-9]*(\.[0-9]+)?/, 0 ] },
    { name => 'gain', required => 0, regex => [ qr/-?[0-9]*(\.[0-9]+)?/, 0 ] },
    { name => 'lc_frequency', required => 0, template => 'int' },
    { name => 'dyn_amount', required => 0, template => 'int' },
    { name => 'phase', required => 0, template => 'int' },
    { name => 'mono', required => 0, template => 'int' },
    (map +{ name => $_, required => 0, enum => [0,1] }, @booleans),
  );
  return 404 if $f->{_err};

  my %set;
  defined $f->{$_} and ($set{"$_ = ?"} = $f->{$_})
    for(@booleans, qw|source_a source_b source_c source_d insert_source mod_level lc_frequency gain dyn_amount phase mono|);

  $self->dbExec('UPDATE module_config !H WHERE number = ?', \%set, $f->{item}) if keys %set;
  _col $f->{field}, { number => $f->{item}, $f->{field} => $f->{$f->{field}} },
    $f->{field} =~ /source/ ? $self->dbAll(q|SELECT number, label, active FROM matrix_sources ORDER BY number|) : ();
}


sub eqajax {
  my($self, $nr) = @_;

  my @num = (regex => [ qr/-?[0-9]*(\.[0-9]+)?/, 0 ]);
  my $f = $self->formValidate(map +(
    { name => "eq_band_${_}_range", @num },
    { name => "eq_band_${_}_level", @num },
    { name => "eq_band_${_}_freq", @num },
    { name => "eq_band_${_}_bw", @num },
    { name => "eq_band_${_}_type", enum => [ 0..7 ] },
  ), 1..6);
  return 404 if $f->{_err};

  my %set = map +("$_ = ?" => $f->{$_}),
    map +("eq_band_${_}_range", "eq_band_${_}_level", "eq_band_${_}_freq", "eq_band_${_}_bw", "eq_band_${_}_type"), 1..6;
  $self->dbExec('UPDATE module_config !H WHERE number = ?', \%set, $nr);
  _eqtable $f;
}


1;


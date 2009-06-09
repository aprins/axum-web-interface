
package AXUM::Handler::Module;

use strict;
use warnings;
use YAWF ':html';


YAWF::register(
  qr{module} => \&overview,
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


1;


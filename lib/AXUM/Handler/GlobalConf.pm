
package AXUM::Handler::GlobalConf;

use strict;
use warnings;
use YAWF ':html';


YAWF::register(
  qr{globalconf} => \&conf,
  qr{ajax/globalconf} => \&ajax,
);


sub _col {
  my($n, $v) = @_;
  if($n eq 'samplerate') {
    a href => '#', onclick => sprintf('return conf_select("globalconf", 0, "samplerate", %d, this, "samplerates")', $v),
      sprintf '%.1f kHz', $v/1000;
  }
  if($n eq 'ext_clock') {
    a href => '#', onclick => sprintf('return conf_set("globalconf", 0, "ext_clock", %d, this)', $v?0:1),
      $v ? 'On' : 'Off';
  }
  if($n eq 'level_reserve') {
    a href => '#', onclick => sprintf('return conf_select("globalconf", 0, "level_reserve", %d, this, "reslevels")', $v),
      sprintf '%d dB', 10-$v;
  }
  if($n =~ /routing_preset_([1-8])_label/) {
    a href => '#', onclick => sprintf('return conf_text("globalconf", 0, "%s", "%s", this)', $n, $v), $v;
  }
  if($n eq 'use_module_defaults') {
    a href => '#', onclick => sprintf('return conf_set("globalconf", 0, "use_module_defaults", %d, this)', $v?0:1),
      $v ? 'Yes' : 'No';
  }
}


sub conf {
  my $self = shift;

  my @cols = (map "routing_preset_${_}_label", 1..8);
  my $conf = $self->dbRow('SELECT samplerate, ext_clock, headroom, level_reserve, use_module_defaults,
                           !s FROM global_config', join ', ', @cols);

  $self->htmlHeader(page => 'globalconf', title => 'Global configuration');
  div id => 'samplerates', class => 'hidden'; Select;
   option value => $_, sprintf '%.1f kHz', $_/1000 for (32000, 44100, 48000);
  end; end;
  div id => 'reslevels', class => 'hidden'; Select;
   option value => 10-$_, "$_ dB", for (0, 10);
  end; end;
  table;
   Tr; th colspan => 2, 'Global configuration'; end;
   Tr; th 'Samplerate';    td; _col 'samplerate', $conf->{samplerate}; end; end;
   Tr; th 'Extern clock';  td; _col 'ext_clock', $conf->{ext_clock}; end; end;
   Tr; th 'Headroom';      td sprintf '%.1f dB', $conf->{headroom}; end;
   Tr; th 'Level reserve'; td; _col 'level_reserve', $conf->{level_reserve}; end; end;
   Tr; th; lit 'If no preset,<BR>use defaults'; end; td; _col 'use_module_defaults', $conf->{use_module_defaults}; end; end;
  end;
  br;
  table;
   Tr; th colspan => 2, 'Routing preset'; end;
   Tr; th 'Number'; th 'Label'; end;
   for (1..8) {
     Tr; th "$_"; td; _col "routing_preset_${_}_label", $conf->{"routing_preset_${_}_label"}; end; end;
   }
  end;
  $self->htmlFooter;
}


sub ajax {
  my $self = shift;

  my $f = $self->formValidate(
    { name => 'field', template => 'asciiprint' },
    { name => 'samplerate', required => 0, enum => [32000, 44100, 48000] },
    { name => 'ext_clock', required => 0, enum => [0,1] },
    { name => 'level_reserve', required => 0, enum => [0,10] },
    { name => 'use_module_defaults', required => 0, enum => [0,1] },
    (map +{ name => "routing_preset_${_}_label", required => 0, maxlength => 32, minlength => 1 }, 1..8),
  );
  return 404 if $f->{_err};

  my %set = map +("$_ = ?", $f->{$_}), grep defined $f->{$_}, qw|samplerate ext_clock level_reserve use_module_defaults|, (map("routing_preset_${_}_label", 1..8));
  $self->dbExec('UPDATE global_config !H', \%set) if keys %set;
  _col $f->{field}, $f->{$f->{field}};
}


1;


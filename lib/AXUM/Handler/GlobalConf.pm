
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
}


sub conf {
  my $self = shift;

  my $conf = $self->dbRow('SELECT samplerate, ext_clock, headroom, level_reserve FROM global_config');

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
  end;
  $self->htmlFooter;
}


sub ajax {
  my $self = shift;

  my $f = $self->formValidate(
    { name => 'field', template => 'asciiprint' },
    { name => 'samplerate', required => 0, enum => [32000, 44100, 48000] },
    { name => 'ext_clock', required => 0, enum => [0,1] },
    { name => 'level_reserve', required => 0, enum => [0,10] }
  );
  return 404 if $f->{_err};

  my %set = map +("$_ = ?", $f->{$_}), grep defined $f->{$_}, qw|samplerate ext_clock level_reserve|;
  $self->dbExec('UPDATE global_config !H', \%set) if keys %set;
  _col $f->{field}, $f->{$f->{field}};
}


1;


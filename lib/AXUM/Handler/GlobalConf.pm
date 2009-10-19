
package AXUM::Handler::GlobalConf;

use strict;
use warnings;
use YAWF ':html';

YAWF::register(
  qr{globalconf} => \&conf,
  qr{ajax/globalconf} => \&ajax,
  qr{ipclock} => \&ipclock,
  qr{ajax/tz_lst} => \&timezone_lst,
  qr{ajax/set_tz} => \&set_tz,
  qr{ajax/ip} => \&set_ip,
  qr{ajax/ntp} => \&set_ntp,
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
  if($n eq 'auto_momentary') {
    a href => '#', onclick => sprintf('return conf_set("globalconf", 0, "auto_momentary", %d, this)', $v?0:1),
      $v ? 'Yes' : 'No';
  }
  if($n =~ /routing_preset_([1-8])_label/) {
    a href => '#', onclick => sprintf('return conf_text("globalconf", 0, "%s", "%s", this)', $n, $v), $v;
  }
  if($n eq 'use_module_defaults') {
    a href => '#', onclick => sprintf('return conf_set("globalconf", 0, "use_module_defaults", %d, this)', $v?0:1),
      $v ? 'Yes' : 'No';
  }
  if ($n =~ /net_(ip|mask|gw)/) {
    a href => '#', onclick => sprintf('return conf_text("ip", 0, "%s", "%s", this)', $n, $v), $v;
  }
  if ($n eq 'ntp_server') {
    $v = "0.0.0.0" if not $v;
    txt "0.pool.ntp.org\n";
    txt "1.pool.ntp.org\n";
    txt "2.pool.ntp.org\n";
    txt "NMEA GPS on USB (/dev/ttyUSB0)\n";
    a href => '#', onclick => sprintf('return conf_text("ntp", 0, "%s", "%s", this)', $n, $v), ($v eq "0.0.0.0" ? ("optional ntp server") : ($v));
  }
  if ($n eq 'timezone') {
    a href => '#', onclick => sprintf('return conf_tz(this)'), $v ? ($v) : ('Select timezone');
  }
}


sub conf {
  my $self = shift;

  my @cols = (map "routing_preset_${_}_label", 1..8);
  my $conf = $self->dbRow('SELECT samplerate, ext_clock, headroom, level_reserve, auto_momentary, use_module_defaults,
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
   Tr; th 'Fader top level'; td; _col 'level_reserve', $conf->{level_reserve}; end; end;
   Tr; th 'Auto momentary'; td; _col 'auto_momentary', $conf->{auto_momentary}; end; end;
   Tr; th; lit 'If no source preset,<BR>use module defaults'; end; td; _col 'use_module_defaults', $conf->{use_module_defaults}; end; end;
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
    { name => 'auto_momentary', required => 0, enum => [0,1] },
    { name => 'use_module_defaults', required => 0, enum => [0,1] },
    (map +{ name => "routing_preset_${_}_label", required => 0, maxlength => 32, minlength => 1 }, 1..8),
  );
  return 404 if $f->{_err};

  my %set = map +("$_ = ?", $f->{$_}), grep defined $f->{$_}, qw|samplerate ext_clock level_reserve use_module_defaults auto_momentary|, (map("routing_preset_${_}_label", 1..8));
  $self->dbExec('UPDATE global_config !H', \%set) if keys %set;
  _col $f->{field}, $f->{$f->{field}};
}

sub ipclock
{
  my $self = shift;
  my @array;

  my ($ip, $mask, $gw);
  open(FILE, '/etc/conf.d/ip');
  @array = <FILE>;
  for my $i (0..$#array)
  {
    $array[$i] =~ m/^net_ip="(.*)"/ ? ($ip = $1) : ();
    $array[$i] =~ m/^net_mask="(.*)"/ ? ($mask = $1) : ();
    $array[$i] =~ m/^net_gw="(.*)"/ ? ($gw = $1) : ();
  }
  close FILE;

  my $tz;
  open(FILE, '/etc/conf.d/timezone');
  @array = <FILE>;
  for my $i (0..$#array)
  {
    $array[$i] =~ m/^user_timezone="(.*)"/;
    $tz = $1;
  }
  close FILE;

  my $ntp_server = "0.0.0.0";
  open(FILE, '/etc/conf.d/ntp');
  @array = <FILE>;
  for my $i (0..$#array)
  {
    $array[$i] =~ m/^server (.*)/;
    $ntp_server = $1;
  }
  close FILE;

  $self->htmlHeader(page => 'ipclock', section => 'timezonde', title => "Timezone configuration");

  table;
  Tr; th colspan => 2, "IP"; end;
  Tr; th colspan => 2; i "(effective after reboot)"; end;
  Tr; th "Address"; td; _col 'net_ip', $ip; end; end;
  Tr; th "Subnet mask:"; td; _col 'net_mask', $mask; end; end;
  Tr; th "Gateway"; td; _col 'net_gw', $gw; end; end;
  Tr class => 'empty'; th colspan => 2; end; end;
  Tr; th colspan => 2, "Clock";
  Tr; th colspan => 2; i "(effective after reboot)"; end;
  Tr; th "Current"; td `date`;
  Tr; th "time zone"; td; _col 'timezone', $tz; end;
  Tr; th "NTP servers"; td; _col 'ntp_server', $ntp_server; end;
  end;
  end;

  $self->htmlFooter;
}

sub timezone_lst {
  my $self = shift;

  my %cnames;

  open(FILE, '/usr/share/zoneinfo/iso3166.tab');
  while (<FILE>) {
    next if /^\#/;
    chomp;
    (my $ccode, my $cname) = split("\t");

    push @{ $cnames{$ccode} }, $cname;
  }

  my %categories;
  my %countries;
  my %localarea;
  my %tzcomment;

  open(FILE, '/usr/share/zoneinfo/zone.tab');
  while (<FILE>) {
    next if /^\#/;
    chomp;
    (my $ccode, undef, my $tz, my $comment) = split("\t");
    (my $cat, my $name, my $place) = split /\//, $tz;

    push(@{ $tzcomment{$tz} }, $comment);

    my $add = 1;
    foreach my $i (@{ $localarea{$name}}) {
      if ($i eq $place) {
        $add = 0;
      }
    }
    push(@{ $localarea{$name} }, $place) if ($add == 1);

    $add = 1;
    foreach my $i (@{ $countries{$ccode}}) {
      if ($i eq $name) {
        $add = 0;
      }
    }
    push(@{ $countries{$ccode} }, $name) if ($add == 1);

    $add = 1;
    foreach my $i (@{ $categories{$cat} }) {
      if ($i eq $ccode) {
       $add = 0;
     }
    }
    push(@{ $categories{$cat} }, $ccode) if ($add == 1);
  }

  my %tz_lst;
  my $cnt_continent = 0;
  for my $c (sort keys %categories )
  {
    foreach my $d (@{$categories{$c}}) {
      foreach my $e (@{$countries{$d}}) {
        foreach my $f (@{$localarea{$e}}) {
          my $tz = "$c/$e";
          my $locationname = "$e";
          if ($f) {
            $locationname .= "/$f";
            $tz .= "/$f";
          }
          my $comment = @{$tzcomment{$tz}}[0];

          if (not $comment)
          {
            my @cats;
            for my $k (sort keys %categories) {
              foreach (@{$categories{$k}}) {
                if ($_ eq $d) {
                  my $new_tz = "$k/$e";
                  if ($f) {
                    $new_tz .= "/$f";
                  }
                  if (not $comment)
                  {
                    $comment = @{$tzcomment{$new_tz}}[0];
                    $tz = $new_tz;
                  }
                }
              }
            }
          }
          if ($comment) {
            $tz_lst{$c}{"@{$cnames{$d}}"}{$comment} = $tz;
          } else {
            $tz_lst{$c}{"@{$cnames{$d}}"}{''} = $tz;
          }
        }
      }
    }
  }

  #make continents and oceans
  div id => 'tz_main';
  Select;
  my $cnt_c = 0;
  for (sort keys %tz_lst)
  {
    option value => $cnt_c, "$_";
    $cnt_c++;
  }
  end;
  end;

  #make countries in continents and oceans
  $cnt_c=0;
  for my $c (sort keys %tz_lst)
  {
    div id => "cont_$cnt_c";
    Select;
    my $cnt_d = 0;
    for (sort keys %{$tz_lst{$c}})
    {
      option value => $cnt_d, "$_";
      $cnt_d++;
    }
    end;
    end;
    $cnt_c++;
  }

  #make local area's
  $cnt_c=0;
  for my $c (sort keys %tz_lst)
  {
    my $cnt_d = 0;
    for my $d (sort keys %{$tz_lst{$c}})
    {
      my $size = keys( %{$tz_lst{$c}{$d}});
      {
        div id => "region_$cnt_c/$cnt_d";
         Select;
         for (sort keys %{$tz_lst{$c}{$d}})
         {
          option value => $tz_lst{$c}{$d}{$_}, "$_";
         }
         end;
        end;
      }
      $cnt_d++;
    }
    $cnt_c++;
  }
}

sub set_tz {
  my $self = shift;

  my $f = $self->formValidate(
    { name => 'tz', required => 1, 'asciiprint' },
  );
  return 404 if $f->{_err};

  my @array;
  open(FILE, '/etc/conf.d/timezone');
  @array = <FILE>;
  for my $i (0..$#array)
  {
    $array[$i] =~ s/^user_timezone="(.*)"/user_timezone="$f->{tz}"/;
  }
  my @result = grep(/[^\s]/,@array);
  close FILE;

  open(FILE, '>/etc/conf.d/timezone');
  print FILE @result;
  close FILE;

  _col 'timezone', $f->{tz};
}

sub set_ip {
  my $self = shift;

  my $f = $self->formValidate(
    { name => 'field', template => 'asciiprint' },
    { name => 'net_ip', required => 0, regex => [ qr/\b(?:\d{1,3}\.){3}\d{1,3}\b/ ], 0},
    { name => 'net_mask', required => 0, regex => [ qr/\b(?:\d{1,3}\.){3}\d{1,3}\b/ ], 0},
    { name => 'net_gw', required => 0, regex => [ qr/\b(?:\d{1,3}\.){3}\d{1,3}\b/ ], 0},
  );
  return 404 if $f->{_err};

  my @array;
  open(FILE, '/etc/conf.d/ip');
  @array = <FILE>;
  for my $i (0..$#array) {
    if ($f->{$f->{field}}) {
      $array[$i] =~ s/^$f->{field}="(.*)"/$f->{field}="$f->{$f->{field}}"/;
    }
  }
  my @result = grep(/[^\s]/,@array);
  close FILE;

  open(FILE, '>/etc/conf.d/ip');
  print FILE @result;
  close FILE;

  _col $f->{field}, $f->{$f->{field}};
}

sub set_ntp {
  my $self = shift;

  my $f = $self->formValidate(
    { name => 'ntp_server', required => 1, 'url'},
  );
  return 404 if $f->{_err};

  my @array;
  open(FILE, '/etc/conf.d/ntp');
  @array = <FILE>;
  for my $i (0..$#array) {
    $array[$i] =~ s/^server (.*)/server $f->{ntp_server}/;
  }
  my @result = grep(/[^\s]/,@array);
  close FILE;

  open(FILE, '>/etc/conf.d/ntp');
  print FILE @result;
  close FILE;

  _col 'ntp_server', $f->{ntp_server};
}


1;


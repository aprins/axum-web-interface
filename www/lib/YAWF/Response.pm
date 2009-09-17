
package YAWF::Response;


use strict;
use warnings;
use Exporter 'import';


our @EXPORT = qw|
  resInit resHeader resBuffer resFd resStatus resRedirect resFinish
|;


# Initialises response data and resets all headers and content to their
# defaults. This method can be called mutliple times per request to clear
# any previous changes and to create a new response.
sub resInit {
  my $self = shift;

  $self->{_YAWF}{Res} = {
    status => 200,
    headers => [
      'Content-Type' => 'text/html; charset=UTF-8',
      'X-Powered-By' => 'Perl-YAWF',
    ],
    content => '',
  };

  open $self->{_YAWF}{Res}{fd}, '>', \$self->{_YAWF}{Res}{content};

  # enable output compression by default if the PerlIO::gzip module is available
  # (we don't check for browser support or even content, but it's possible to
  #  disable the gzip compression layer later on via resBuffer)
  eval { require PerlIO::gzip; };
  if(!$@) {
    binmode $self->{_YAWF}{Res}{fd}, ':gzip';
    $self->resHeader('Content-Encoding' => 'gzip');
  }
  binmode $self->{_YAWF}{Res}{fd}, ':utf8';
}


# Arguments       Action
#  name            returns list of values of the header, first found in scalar context, undef if not exists
#  name, value     sets header, overwrites existing header with same name, removes duplicates
#  name, undef     removes header
#  name, value, 1  adds header, not checking whether it already exists
# Header names are case-insensitive
sub resHeader {
  my($self, $name, $value, $add) = @_;
  my $h = $self->{_YAWF}{Res}{headers};

  if($add) {
    push @$h, $name, $value;
    return $value;
  }

  my @h;
  my @r;
  for (@$h ? 0..$#$h/2 : ()) {
    if(lc($h->[$_*2]) eq lc($name)) {
      push @h, $h->[$_*2+1];
      if(@_ == 3 && defined $value) {
        $h->[$_*2+1] = $value;
        push @r, $_ if @h > 1
      } elsif(@_ == 3) {
        push @r, $_;
      }
    }
  }

  push @$h, $name, $value if @_ == 3 && defined $value && !@h;

  splice @$h, $r[$_]*2-$_*2, 2
    for (@r ? 0..$#r : ());

  return @_ == 3 || @_ == 2 && !wantarray ? $h[0] : @h;
}


# Argument    Action
#  none        Returns whether gzip compression is enabled or not
#  undef       Clears the internal buffer
#  0           Clears buffer and disables gzip
#  1           Clears and enables gzip
# Enabling compression if PerlIO::gzip isn't installed will result in an error
sub resBuffer {
  my $self = shift;
  my $i = $self->{_YAWF}{Res};
  my $h = $self->resHeader('Content-Encoding');
  $h = $h && $h eq 'gzip';

  if(@_) {
    # clear buffer
    close $i->{fd};
    $i->{content} = '';
    open $i->{fd}, '>', \$i->{content};

    if(!defined $_[0] && $h || $_[0]) {
      binmode $i->{fd}, ':gzip';
      $self->resHeader('Content-Encoding', 'gzip');
    } else {
      $self->resHeader('Content-Encoding', undef);
    }
    binmode $i->{fd}, ':utf8';
  }

  $h = $self->resHeader('Content-Encoding');
  return $h && $h eq 'gzip';
}


# Returns the file descriptor where output functions can 'print' to
sub resFd {
  return shift->{_YAWF}{Res}{fd};
}


# Returns or sets the HTTP status
sub resStatus {
  my($self, $new) = @_;
  $self->{_YAWF}{Res}{status} = $new if $new;
  return $self->{_YAWF}{Res}{status};
}


# Redirect to an other page, accepts an URL (relative to current hostname) and
# an optional type consisting of 'temp' (temporary) or 'post' (after posting a form).
# No type argument means a permanent redirect.
sub resRedirect {
  my($self, $url, $type) = @_;

  $self->resInit;
  my $fd = $self->resFd();
  print $fd 'Redirecting...';
  $self->resHeader('Location' => $self->reqBaseURI().$url);
  $self->resStatus(!$type ? 301 : $type eq 'temp' ? 307 : 303);
}


# Send everything we have buffered to the client
sub resFinish {
  my $self = shift;
  my $i = $self->{_YAWF}{Res};

  close $i->{fd};
  $self->resHeader('Content-Length' => length($i->{content}));

  printf "Status: %d\r\n", $i->{status};
  printf "%s: %s\r\n", $i->{headers}[$_*2], $i->{headers}[$_*2+1]
    for (0..$#{$i->{headers}}/2);
  print  "\r\n";
  print  $i->{content};

  # free the memory used for the reponse data
  $self->resInit;
}




1;



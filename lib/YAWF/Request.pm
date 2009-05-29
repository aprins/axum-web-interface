
package YAWF::Request;

use strict;
use warnings;
use Encode 'decode_utf8';
use Exporter 'import';
use CGI::Minimal;

our @EXPORT = qw|
  reqInit reqParam reqUploadMIME reqUploadFileName reqSaveUpload reqCookie
  reqMethod reqHeader reqPath reqBaseURI reqURI reqHost reqIP
|;


sub reqInit {
  my $self = shift;

  # lighttpd doesn't always split the query string from REQUEST_URI
  if($ENV{SERVER_SOFTWARE}||'' =~ /lighttpd/) {
    ($ENV{REQUEST_URI}, $ENV{QUERY_STRING}) = split /\?/, $ENV{REQUEST_URI}, 2
      if ($ENV{REQUEST_URI}||'') =~ /\?/;
  }

  # reset and re-initialise some vars to make CGI::Minimal work in FastCGI
  CGI::Minimal::reset_globals;
  CGI::Minimal::allow_hybrid_post_get(1);
  CGI::Minimal::max_read_size(10*1024*1024); # allow 10MB of POST data

  my $cgi = CGI::Minimal->new();
  die "Truncated post request\n" if $cgi->truncated;

  $self->{_YAWF}{Req}{c} = $cgi;
}



# wrapper around CGI::Minimal's param(), only properly encodes everything to
# Perl's internal UTF-8 format, and returns an empty string on undef.
sub reqParam {
  my($s, $n) = @_;
  if($n) {
    return wantarray
      ? map { defined $_ ? decode_utf8 $_ : '' } $s->{_YAWF}{Req}{c}->param($n)
      : defined $s->{_YAWF}{Req}{c}->param($n) ? decode_utf8 $s->{_YAWF}{Req}{c}->param($n) : '';
  }
  return $s->{_YAWF}{Req}{c}->param();
}


# returns the MIME Type of an uploaded file, requires form name as argument,
# can return an array if multiple file uploads have the same form name
sub reqUploadMIME {
  my $c = shift->{_YAWF}{Req}{c};
  return $c->param_mime(shift);
}


# same as reqUploadMIME, only this one fetches filenames
sub reqUploadFileName {
  my $c = shift->{_YAWF}{Req}{c};
  return $c->param_filename(shift);
}


# saves file contents identified by the form name to the specified file
# (doesn't support multiple file upload using the same form name yet)
sub reqSaveUpload {
  my($s, $n, $f) = @_;
  open my $F, '>', $f or die "Unable to write to $f: $!";
  print $F $s->{_YAWF}{Req}{c}->param($n);
  close $F;
}


sub reqCookie {
  require CGI::Cookie::XS;
  my $c = CGI::Cookie::XS->fetch;
  return $c && ref($c) eq 'HASH' && $c->{$_[1]} ? decode_utf8 $c->{$_[1]}[0] : '';
}


sub reqMethod {
  return ($ENV{REQUEST_METHOD}||'') =~ /post/i ? 'POST' : 'GET';
}


# Returns list of header names when no argument is passed
#   (may be in a different order and can have different casing than
#    the original headers - CGI doesn't preserve that information)
# Returns value of the specified header otherwise, header name is
#   case-insensitive
sub reqHeader {
  my($self, $name) = @_;
  if($name) {
    (my $v = uc $_[1]) =~ tr/-/_/;
    return $ENV{"HTTP_$v"}||'';
  } else {
    return (map {
      if(/^HTTP_/) { 
        (my $h = lc $_) =~ s/_([a-z])/-\U$1/g;
        $h =~ s/^http-//;
        $h;
      } else { () }
    } sort keys %ENV);
  }
}


# returns the path part of the current URI, excluding the leading slash
sub reqPath {
  (my $u = $ENV{REQUEST_URI}) =~ s{^/+}{};
  return $u;
}


# returns base URI, excluding trailing slash
sub reqBaseURI {
  return ($ENV{HTTPS} ? 'https://' : 'http://').$ENV{HTTP_HOST};
}


# returns undef if the request isn't initialized yet
sub reqURI {
  return $ENV{HTTP_HOST} && defined $ENV{REQUEST_URI} ?
    ($ENV{HTTPS} ? 'https://' : 'http://').$ENV{HTTP_HOST}.$ENV{REQUEST_URI}.($ENV{QUERY_STRING} ? '?'.$ENV{QUERY_STRING} : '')
    : undef;
}


sub reqHost {
  return $ENV{HTTP_HOST};
}


sub reqIP {
  return $ENV{REMOTE_ADDR};
}


1;



package YAWF::Misc;
# Yeah, just put all miscellaneous functions in one module!
# Geez, talk about being sloppy...

use strict;
use warnings;
use Exporter 'import';


our @EXPORT = ('mail', 'formValidate');


# Some pre-defined templates. It's possible to add templates at any time
# and from any file by executing something like:
#  $YAWF::Misc::templates{templatename} = qr/regex/;
our %templates = (
  mail       => qr/^[^@<>]+@[^@.<>]+(?:\.[^@.<>]+)+$/,
  url        => qr/^(http|https):\/\/[\w\-_]+(\.[\w\-_]+)+([\w\-\.,@?^=%&:\/~\+#]*[\w\-\@?^=%&\/~\+#])?$/,
  asciiprint => qr/^[\x20-\x7E]*$/,
  int        => qr/^-?\d+$/,
  pname      => qr/^[a-z0-9-]*$/,
);


# Arguments: list of hashes representing a form item with validation rules
#  {
#    name       => name of the form
#    multi      => 0/1, multiple form fields with the same name (see below)
#    default    => value to return if the field is left empty
#    required   => 0/1, whether this field is required, defaults to 1
#    whitespace => 0/1, removes any whitespace around the field before
#                  validating, also removes all occurences of \r. defaults to 1
#    maxlength  => maximum length of the field
#    minlength  => minimum required length
#    enum       => [ value must be present in a set list ]
#    template   => one of the templates as defined in %templates
#    regex      => [ qr/ regex /, "message for the user" ]
#    func       => [ sub { external subroutine }, "message for the user" ]
#  }
#
# The subroutine passed with the func rule will receive a form value as it's
# first argument and must return either any false value if the field doesn't
# validate or any true value otherwise. The function is allowed to modify it's
# first argument to change the value of the field.
#
# Returns a hash with form names as keys and their value as argument, and
# a special key called '_err' in case there were errors. The value of this
# hash item is an array of failed test cases, each represented as an array
# with a list of: name of the field that failed validation and the rule on
# which the validation failed (the key-value pair specified as argument)
#
# If the multi rule is specified, the returned value will be an arrayref
# with the values of each item. If no fields were found with that name, the
# arrayref will be empty. The validator will stop checking the other values
# after one has failed.
sub formValidate {
  my($self, @fields) = @_;

  my @err;
  my %ret;

  for my $f (@fields) {
    $f->{required}++ if not exists $f->{required};
    $f->{whitespace}++ if not exists $f->{whitespace};
    my @values = $f->{multi} ? $self->reqParam($f->{name}) : ( scalar $self->reqParam($f->{name}) );
    $values[0] = '' if !@values;
    for (@values) {
      my $valid = _validate($_, $f);
      if(!ref $valid) {
        $_ = $valid;
        next;
      }
      push @err, [ $f->{name}, $$valid, $f->{$$valid} ];
      last;
    }
    $ret{$f->{name}} = $f->{multi} ? \@values : $values[0];
  }

  $ret{_err} = \@err if @err;
  return \%ret;
}


# Internal function used by formValidate, checks one value on the validation
# rules, returns scalarref containing the failed rule on error, new value
# otherwise
sub _validate { # value, { rules }
  my($v, $r) = @_;

  # remove whitespace
  if($v && $r->{whitespace}) {
    $v =~ s/\r//g;
    $v =~ s/^[\s\n]+//;
    $v =~ s/[\s\n]+$//;
  }

  # empty
  if(!$v && length $v < 1 && $v ne '0') {
    return \'required' if $r->{required};
    return exists $r->{default} ? $r->{default} : undef;
  }

  # length
  return \'minlength' if $r->{minlength} && length $v < $r->{minlength};
  return \'maxlength' if $r->{maxlength} && length $v > $r->{maxlength};
  # enum
  return \'enum'      if $r->{enum} && !grep $_ eq $v, @{$r->{enum}};
  # template
  return \'template'  if $r->{template} && $v !~ /$templates{$r->{template}}/;
  # regex
  return \'regex'     if $r->{regex} && $v !~ /$r->{regex}[0]/;
  # function
  return \'func'      if $r->{func} && !$r->{func}[0]->($v);
  # passed validation
  return $v;
}



# A simple mail function, body and headers as arguments. Usage:
#  $self->mail('body', header1 => 'value of header 1', ..);
sub mail {
  my $self = shift;
  my $body = shift;
  my %hs = @_;

  die "No To: specified!\n" if !$hs{To};
  die "No Subject: specified!\n" if !$hs{Subject};
  $hs{'Content-Type'} ||= 'text/plain; charset=\'UTF-8\'';
  $hs{From} ||= $self->{_YAWF}{mail_from};
  $body =~ s/\r?\n/\n/g;

  my $mail = '';
  foreach (keys %hs) {
    $hs{$_} =~ s/[\r\n]//g;
    $mail .= sprintf "%s: %s\n", $_, $hs{$_};
  }
  $mail .= sprintf "\n%s", $body;

  if(open(my $mailer, '|-:utf8', "$self->{_YAWF}{mail_sendmail} -t -f '$hs{From}'")) {
    print $mailer $mail;
    die "Error running sendmail ($!)"
      if !close($mailer);
  } else {
    die "Error opening sendail ($!)";
  }
}


1;

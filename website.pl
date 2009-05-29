#!/usr/bin/perl

package AXUM;

use strict;
use warnings;

use Cwd 'abs_path';
our $ROOT;
BEGIN { ($ROOT = abs_path $0) =~ s{/website\.pl$}{}; }

use lib "$ROOT/lib";
use YAWF;


YAWF::init(
  namespace => 'AXUM',
  logfile => "$ROOT/log", # this logfile is mostly for debugging,
                          # can be disabled on production box
  debug => 1,
);


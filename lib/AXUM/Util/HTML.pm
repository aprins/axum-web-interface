
package AXUM::Util::HTML;

use strict;
use warnings;
use YAWF ':html';
use Exporter 'import';

our @EXPORT = qw| htmlHeader htmlFooter htmlSourceList OEMFullProductName |;


sub htmlHeader {
  my($self, %o) = @_;
  html;
   head;
    title $o{title};
    Link href => '/style.css', rel => 'stylesheet', type => 'text/css';
    script type => 'text/javascript', src => '/scripts.js', ' ';
   end;
   body;
    div id => $_, '' for (qw| header header_left header_right border_left border_right
      footer footer_left footer_right hinge_top hinge_bottom|);
    div id => 'loading', 'Saving changes, please wait...';

    div id => 'navigate';
     a href => '/', OEMFullProductName();
     lit " &raquo; ";
     a href => '/', 'Main menu' if $o{page} eq 'home';
     a href => '/ipclock', 'IP/Clock configuration' if $o{page} eq 'ipclock';
     a href => '/buss', 'Buss configuration' if $o{page} eq 'buss';
     a href => '/monitorbuss', 'Monitor buss configuration' if $o{page} eq 'monitorbuss';
     if ($o{page} eq 'source') {
       a href => '/source', 'Source configuration' if $o{page} eq 'source';
       if($o{section} eq 'generate') {
         lit " &raquo; ";
         a href => "/source/$o{section}", "Generate";
       }
       elsif ($o{section})
       {
         lit " &raquo; ";
         a href => "/source/$o{section}/preset", "Source $o{section} preset";
       }
     }
     a href => '/externsrc', 'Extern source configuration' if $o{page} eq 'externsrc';
     a href => '/dest', 'Destination configuration' if $o{page} eq 'dest';
     a href => '/talkback', 'Talkback configuration' if $o{page} eq 'talkback';
     if ($o{page} eq 'module' || $o{page} eq 'modulerouting') {
       a href => '/module', 'Module configuration';
       if($o{section}) {
         lit " &raquo; ";
         a href => "/module/$o{section}", "Module $o{section}";
         if($o{page} eq 'modulerouting') {
           lit " &raquo; ";
           a href => "/module/$o{section}/route", 'Routing';
         }
       }
     }
     a href => '/module/assign', 'Module assignment' if $o{page} eq 'moduleassign';
     a href => '/globalconf', 'Global configuration' if $o{page} eq 'globalconf';
     if($o{page} eq 'surface') {
       a href => '/surface', 'Surface configuration';
       if($o{section}) {
         lit " &raquo; ";
         a href => "/surface/$o{section}", "Address $o{section}";
       }
     }
     if($o{page} eq 'rack') {
       a href => '/rack', 'Rack configuration';
       if($o{section}) {
         lit " &raquo; ";
         a href => "/rack/$o{section}", "Address $o{section}";
       }
     }
     if($o{page} eq 'service') {
       a href => '/service', 'Service';
       if ($o{section} eq 'mambanet') {
         lit " &raquo; ";
         a href => '/service/mambanet', 'MambaNet configuration';
       }
       if($o{section} eq 'predefined') {
         lit " &raquo; ";
         a href => '/service/predefined', 'Predefined';
       }
       if($o{section} eq 'functions') {
         lit " &raquo; ";
         a href => '/service/functions', 'Functions';
       }
     }
    end;
    div id => 'content';
}


sub htmlFooter {
    end; # /div content
   end; # /body
  end; # /html
}


sub htmlSourceList {
  my($self, $lst, $name, $min) = @_;
  div id => $name, class => 'hidden';
   Select;
    my $last = '';
    for (@$lst) {
      next if $min && $_->{type} eq 'n-1';
      if($last ne $_->{type}) {
        end if $last;
        $last = $_->{type};
        optgroup label => $last;
      }
      option value => $_->{number}, !$_->{active} ? (class => 'off') : (), $_->{label}
    }
    end if $last;
   end;
  end;
}

sub OEMFullProductName {
  open my $F, "/var/lib/axum/OEMFullProductName" or die "Couldn't open file /var/lib/axum/OEMFullProductName: $!";
  my $n =  <$F>;
  close FILE;
  $n =~ s/\s+$//;
  return $n;
}


1;

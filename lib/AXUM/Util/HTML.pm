
package AXUM::Util::HTML;

use strict;
use warnings;
use YAWF ':html';
use Exporter 'import';

our @EXPORT = qw| htmlHeader htmlFooter htmlSourceList |;


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
     a href => '/', 'AXUM';
     lit " &raquo; ";
     a href => '/', 'Main menu' if $o{page} eq 'home';
     a href => '/buss', 'Buss configuration' if $o{page} eq 'buss';
     a href => '/monitorbuss', 'Monitor buss configuration' if $o{page} eq 'monitorbuss';
     a href => '/source', 'Source configuration' if $o{page} eq 'source';
     a href => '/externsrc', 'Extern source configuration' if $o{page} eq 'externsrc';
     a href => '/dest', 'Destination configuration' if $o{page} eq 'dest';
     a href => '/talkback', 'Talkback configuration' if $o{page} eq 'talkback';
     a href => '/module', 'Module configuration' if $o{page} eq 'module' || $o{page} eq 'modulerouting';
     if($o{section}) {
       lit " &raquo; ";
       a href => "/module/$o{section}", "Module $o{section}";
       if($o{page} eq 'modulerouting') {
         lit " &raquo; ";
         a href => "/module/$o{section}/route", 'Routing';
       }
     }
     a href => '/module/assign', 'Module assignment' if $o{page} eq 'moduleassign';
     a href => '/globalconf', 'Global configuration' if $o{page} eq 'globalconf';
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
    option value => 0, 'none';
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


1;


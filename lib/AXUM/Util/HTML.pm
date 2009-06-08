
package AXUM::Util::HTML;

use strict;
use warnings;
use YAWF ':html';
use Exporter 'import';

our @EXPORT = qw| htmlHeader htmlFooter |;


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
    end;
    div id => 'content';
}


sub htmlFooter {
    end; # /div content
   end; # /body
  end; # /html
}


1;


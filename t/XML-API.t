# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl XML-API.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test;
BEGIN { plan tests => 2 };
require XML::API;
ok(1); # If we made it this far, we're ok.
my $x = XML::API->new(doctype => 'xhtml');
$x->body_open;
$x->_set_id('body');
$x->div('junk with ordered keys?', {key2 => 'val2', key1 => 'val1'});
$x->_goto('body');
$x->li_open();
$x->a({href => '#'}, 'link');
$x->_add('|');
$x->li_close();
$x->div(-class => 'classname', -id => 'idname', 'and the content');
my $j = XML::API->new(element => 'p');
$j->_add('external object');
$j->_parse('<p>some paragraph <a href="p.html">inlinelink</a> and end</p>');
$x->_add($j);
ok(2); # If we made it this far, we're ok.
print STDERR "\nDocument looks like:\n", $x;

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.


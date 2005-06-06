# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl XML-API.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test;
BEGIN { plan tests => 2 };
require XML::API;
ok(1); # If we made it this far, we're ok.
my $x = XML::API->new();
$x->body_open;
$x->_set_id('body');
$x->div('junk');
$x->_goto('body');
ok(2); # If we made it this far, we're ok.
print STDERR "\nDocument looks like:\n", $x->_as_string();

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.


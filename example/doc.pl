#!/usr/bin/perl
# ----------------------------------------------------------------------
# Copyright (C) 2005 Mark Lawrence <nomad@null.net>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# ----------------------------------------------------------------------
# Parse HTML into Perl/XML::API Code
# ----------------------------------------------------------------------

use lib 'lib'; use lib '../lib';
use XML::API;
use Storable qw(freeze thaw);
use Data::Dumper;

if (@ARGV < 1) {
    print STDERR "usage: $0 <file> [tag1 tag2 ...]\n";
    exit 1;
}

my $file = shift;

if ($file eq '-') {
    *FH = *STDIN;
}
elsif (!open(FH, $file)) {
    print STDERR "Could not open $file: $!\n";
    exit 1;
}

my $x = XML::API->new(doctype => 'xhtml');

$x->_parse_allow_tags(@ARGV);
$x->_parse(<FH>);

$x->_print();


__END__

=head1 NAME

XML::API - Perl extension for creating XML documents

=head1 SYNOPSIS

As a simple example the following perl code:

  use XML::API;
  my $x = XML::API->new(doctype => 'xhtml');
  
  $x->head_open();
  $x->title('Test Page');
  $x->head_close();

  $x->body_open();
  $x->div_open({id => 'content'});
  $x->p('A test paragraph');
  $x->div_close();
  $x->body_close();

  $x->_print;

will produce the following nicely rendered output:
  
  <?xml version="1.0" encoding="ISO-8859-1"?>
  <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"
      "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
  <html>
    <head>
      <title>Test Page</title>
    </head>
    <body>
      <div id="content">
        <p>A test paragraph</p>
      </div>
    </body>
  </html>

There are also more powerful and flexible ways to use this module. Read on.

=head1 DESCRIPTION

B<XML::API> is a class for creating XML documents using
object method calls. This class is meant for generating XML
programatically and not for reading or parsing it.

The methods of a B<XML::API> object are derived directly from the XML
Schema Definition document for the desired document type.
A document author calls the desired methods (representing elements) to
create an XML tree in memory which can then be rendered or saved as desired.
The advantage of having the in-memory tree is that you can be very flexible
about when different parts of the document are created and the final output
is always nicely rendered.

It is also worth having a small through about future proofing: Because
your 'xml' is actually 'code' it is potentially possible to change the
output of *all* of your xml by modifying the Perl class. No more hunting
through source files changing strings when the next version of xhtml
comes out.

=head1 TUTORIAL

The first step is to create an object. The 'doctype' attribute determines
the XSD to use (currently only xhtml and rss are distributed with the
distribution):

  use XML::API;
  my $x = XML::API->new(doctype => 'xhtml');

$x is the only object we need for our entire XHTML document. By default
$x consists initially of only the root element ('html') which should be
thought of as the 'current' or 'containing' element. The next step might
be to add a 'head' element. We do this by calling the head_open() method:

  $x->head_open();

Because we have called a *_open() function the 'current' or 'containing'
element is now 'head'. All further elements will be added inside the
'head' element. So lets add a title element and the title content
('Document Title') to our object:

  $x->title('Document Title');

The 'title()' method on its own (ie not 'title_open()') indicates that we
are specifiying the entire title element. Further method calls will
continue to place elements inside the 'head' element until we specifiy we
want to move on by calling the _close method:

  $x->head_close();

This sets the current element back to 'html'.

So, basic elements seem relatively easy. How do we create elements with
attributes? When either the element() or element_open() methods are called
with a hashref argument the keys and values of the hashref become the
attributes:

  $x->body_open({id => 'bodyid'}, 'Content', 'more content');

By the way, both the element() and element_open() methods take arbitrary
numbers of content arguments as shown above. However if you don't want to
specify the content of the element at the time you open it up you can
use the _add() utility method later on:

  $x->div_open();
  $x->_add('Content added after the _open');

The final thing is to close out the elements and render the docment.

  $x->div_close();
  $x->body_close();
  print $x->_as_string();

Because we are not adding any more elements or content it is not strictly
necessary to close out all elements, but consider it good practice.

=head1 METHODS

=head2 new(doctype => '(xhtml|rss)', [ element => 'xxx', strict => bool ])

Create a new XML::API based object. What you get back is actually
an object of type XML::API::<doctype> which is derived from XML::API.
The containing or 'current' element is by default the root element of
the XSD.

You don't have to start with the root element of the specification. If
you wanted for instance to create a standalone 'div' object you can
with the 'element' attribute to the new() call:

  my $div = XML::API->new(doctype => 'xhtml', element => 'div');

You can then add this element to an object that has the root element 
using the _add() method below.

By default strict checking is performed to make sure that the structure
of the document matches the Schema. This can be turned off by setting
'strict' to false (0 or undef).

=head2 $x->element_open({attribute => $value}, $content)

Add a new element to the 'current' element, and set the current element
to be the element just created. Returns a reference (private data type)
to the new element which can be used in the _goto function below.

Ie given that $x currently represents:

  <html>  <---- 'current' element
          <---- future elements/content goes here
  </html>

then $x->head_open({attribute => $value}) means the tree is now:

  <html>
    <head attribute="$value">  <---- 'current' element
                               <---- future elements/content goes here
    </head>
  </html>

=head2 $x->element({attribute => $value}, $content)

Add a new element to the 'current' element but keep the 'current'
element the same. Returns a reference (private data type)
to the new element which can be used in the _goto function below.

Ie given that $x is currently:

  <div>  <---- 'current' element
         <---- future elements/content goes here
  </div>

then $x->p({attribute => $value}, $content) means the tree is now:

  <div>                      <---- still 'current' element
    <p attribute="$value">$content</p>
                             <---- future elements/content goes here
  </div>

If $content is not given (or not added with the _add method) then the
element will be rendered as empty. Eg $x->br() produces:

  <div>                      <---- still 'current' element
    <p attribute="$value">$content</p>
    <br />
                             <---- future elements/content goes here
  </div>

=head2 $x->element_close( )

This does not actually modify the tree but simply tells the object that
future elements will be added to the parent of the current element.
Ie given that $x currently represents:

  <div>
    <p>  <---- 'current' element
      $content
           <---- future elements/content goes here
    </p>
  </div>

then $x->p_close() means the tree is now:

  <div>    <---- 'current' element
    <p>
      $content
    </p>
           <---- future elements go here
  </div>

If you try to call a _close() method that doesn't match the current
element a warning will be issued and the call will fail.

=head2 $x->_add($content)

Adds content to the 'current' element. $content can be either scalar
(string, numeric) or an XML::API element.

=head2 $x->_current( )

Returns a reference (private data type) to the current element.

=head2 $x->_goto($reference)

Change the 'current' element. $reference is the return value of one of
the element_open(), element() or _current() methods.

This is useful if you create the basic structure of your document, but
then later want to go back and modify it or fill in the details.

This method also currently takes a string matching the id= attribute
of an element previously defined, but as this is specific to xhtml
don't rely on it always being around.

=head2 $x->_attrs( )

Allows you to get/set the attributes of the current element. Accepts
and returns and hashref.

=head2 $x->_comment($comment)

Is a shortcut for $x->_add('\n<!--', $content, '-->')

=head2 $x->_cdata( )

Is a shortcut for $x->_add("\n<![CDATA[", @_, " ]]>");

=head2 $x->_as_string( )

Returns the rendered version of the XML document.

=head2 $x->_print( )

A shortcut for "print $x->_as_string()"

=head1 SEE ALSO

L<XML::API::XHTML::Parse>

B<XML::API> was written for the Rekudos framework:  http://rekudos.net/

=head1 AUTHOR

Mark Lawrence E<lt>nomad@null.netE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2004,2005 Mark Lawrence <nomad@null.net>

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

=cut


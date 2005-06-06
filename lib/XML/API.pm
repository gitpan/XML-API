# ----------------------------------------------------------------------
# Copyright (C) 2004 Mark Lawrence <nomad@null.net>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# ----------------------------------------------------------------------
# XML::API::Element - Perl extention for creating XML elements
#
# This is a private package (not to be used outside XML::API) to
# handle XML 'elements', their relationship to each other, and how they
# should be rendered.
# ----------------------------------------------------------------------
package XML::API::Element;

use strict;
use warnings;
use 5.006;
use Carp;

our $Indent = '  ';
our $NL     = "\n";

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;

    my %param = (
        element   => '',
        attrs     => {},
        content   => [],
        parent    => undef,
        debug     => 0,
        @_
    );

    croak 'element not defined' unless(defined($param{element}));
    croak 'attrs not defined'   unless(defined($param{attrs}));
    croak 'content not defined' unless(defined($param{content}));

    if ($param{element} eq '') {
        carp 'usage: new ',__PACKAGE__,'(element => $e)';
        return undef;
    }

    if (defined($param{parent}) and ref($param{parent}) ne $class) {
        carp "parent must be a $class object";
        return undef;
    }

    my $self = \%param;
    bless ($self, $class);
    return $self;
}


sub name {
    my $self = shift;
    return $self->{element};
}


sub parent {
    my $self = shift;
    return $self->{parent};
}


sub add_element {
    my $self = shift;
    my $new_element = new XML::API::Element(@_, parent => $self);
    push(@{$self->{content}}, $new_element);
    return $new_element;
}


sub add_content {
    my $self = shift;
    push(@{$self->{content}}, @_);
}


sub attrs_as_string {
    my $self = shift;
    my @strings;

    while (my ($key, $val) = each %{$self->{attrs}}) {
        push(@strings, $key . '="' . $val . '"');
    }

    return ' ' . join(' ', @strings) if (@strings);
    return '';
}


sub as_string {
    my $self = shift;

    my %param = (
        depth  => 0,
        @_
    );

    my $indent = $Indent x $param{depth};

    #
    # <element att1="val1"
    #
    my $string = $indent   . '<' .
                 $self->{element} .  $self->attrs_as_string;

    #
    #  '/>' or '>'?
    #
    if (!@{$self->{content}}) {
        return $string . ' />' . "\n";
    }
    $string .= '>';

    my $last_was_element = 0;
    my $has_element      = 0;
    foreach my $child (@{$self->{content}}) {
        next unless (defined($child));

        if (ref($child) eq ref($self)) { # is an Element
            $string .= "\n" unless($last_was_element);
            $string .= $child->as_string(depth => $param{depth} + 1);
            $last_was_element = 1;
            $has_element      = 1;
        }
        else {
            $string .= $child;
            $last_was_element = 0;
        }
    }

    #
    # </element>
    #
    if ($has_element and !$last_was_element) {
        $string .= "\n$indent";
    }
    if ($last_was_element) {
        $string .= $indent;
    }
    return $string . '</' . $self->{element} . ">\n";
}


sub fast_string {
    my $self = shift;

    #
    # <element att1="val1"
    #
    my $string = '<' .  $self->{element} .  $self->attrs_as_string;

    #
    #  '/>' or '>'?
    #
    if (!@{$self->{content}}) {
        return $string . ' />';
    }
    $string .= '>';

    foreach my $child (@{$self->{content}}) {
        next unless (defined($child));

        if (ref($child) eq ref($self)) { # is an Element
            $string .= $child->fast_string();
        }
        else {
            $string .= $child;
        }
    }

    #
    # </element>
    #
    return $string . '</' . $self->{element} . '>';
}

sub print {
    my $self = shift;
    print $self->as_string();
}


# ----------------------------------------------------------------------
# XML::API - Perl extension for creating XML documents
# ----------------------------------------------------------------------
package XML::API;
use strict;
use warnings;
use 5.006;
use Carp;
use Storable qw(freeze thaw);

our $VERSION = '0.05';
our $AUTOLOAD;


# ----------------------------------------------------------------------
# Class subroutines
# ----------------------------------------------------------------------

sub new {
    my $proto = shift;
    if ($proto ne __PACKAGE__) {
        croak "$proto must implement it's own new() method";
    }

    my %param = (
        doctype   => 'XHTML',
        element   => '',
        attrs     => {},
        content   => [],
        strict    => 1,
        @_,
    );

    $param{doctype} = uc($param{doctype});
    my $class = 'XML::API::' . $param{doctype};

    if (! $INC{"XML/API/$param{doctype}.pm"}) {
        if (! eval "require $class; 1;") {
            croak "Can't find a class for doctype $param{doctype}";
        }
    }

    return $class->new(%param);
}

sub _thaw {
    return thaw(shift);
}

# ----------------------------------------------------------------------
# Object Methods
# ----------------------------------------------------------------------

#
# This is called by derived classes to set themselves up
#
sub _init {
    my $self = shift;
    my %param = (
        element   => '',
        attrs     => {},
        content   => [],
        strict    => 1,
        @_,
    );

    #
    # Default to the root element if none is specified. The root element and
    # attributes are provided by subroutines overridden in the inheriting
    # class
    #

    if ($param{element} eq '') {
        $param{element} = $self->_root_element();
        $param{attrs}   = $self->_root_attrs();
    }

    $self->{root}    = new XML::API::Element(%param);
    $self->{current} = $self->{root};
    $self->{strict}  = $param{strict};
    $self->{ids}     = {};

    return $self;
}


#
# These must be overridden by derived classes
#
sub _xsd {
    my $self = shift;
    my $ref = ref($self) || $self;
    croak "$ref must overload subroutine '_root_xsd'";
}

sub _root_element {
    my $self = shift;
    my $ref = ref($self) || $self;
    croak "$ref must overload subroutine '_root_element'";
}

sub _root_attrs {
    my $self = shift;
    my $ref = ref($self) || $self;
    croak "$ref must overload subroutine '_root_attrs'";
}

sub _doctype {
    my $self = shift;
    my $ref = ref($self) || $self;
    croak "$ref must overload subroutine '_doctype'";
}


#
# The rest are XML::API public methods
#

sub AUTOLOAD {
    my $self = shift;
    my $element = $AUTOLOAD;

    #
    # Goto to where were are told
    #
    if ($element =~ s/.*::_goto_(.*)$/$1/) {
    }

    my ($open, $close, $new);
    if ($element =~ s/.*::(.*)_open$/$1/) {
          $open = 1;  
    }
    elsif ($element =~ s/.*::(.*)_close$/$1/) {
          $close = 1;  
    }
#    elsif ($element =~ s/.*::new_(.*)$/$1/) {
#          $new = 1;  
#    }
    else  {
        $element =~ s/.*:://;
    }

    croak 'element not defined' unless(defined($element));

    if ($element =~ /^_/) {
        croak "Undefined subroutine &" . ref($self) . "::$element called";
        return undef;
    }

    #
    # Check if we are allowed to do this
    #
    if ($self->{strict}) {
        # $self->_xsd....
    }

    my $attrs   = {};
    my $content = [];
    foreach my $arg (@_) {
        if (ref($arg) eq 'HASH') {
            $attrs = $arg;
        }
        else {
            push(@$content, $arg);
        }
    }


    if ($open) {
        my $new_element = $self->{current}->add_element(element => $element,
                                                        attrs   => $attrs,
                                                        content => $content);
        $self->{current} = $new_element;
        return $new_element;
    }
    elsif ($close) {
        if ($element eq $self->{current}->name()) {
            if ($self->{current}->parent()) {
                $self->{current} = $self->{current}->parent;
                return;
            }
            else {
                carp 'cannot close element "' . $element .
                     '" when it has no parent';
                return;
            }
        }
        else {
            carp 'attempted to close element "' . $element . '" when current ' .
                 'element is "' . $self->{current}->name() . '"';
            return;
        }
    }
    else {
        my $new_element = $self->{current}->add_element(element => $element,
                                                        attrs   => $attrs,
                                                        content => $content);
        return $new_element;
    }
}


sub _current {
    my $self = shift;
    return $self->{current};
}


sub _add {
    my $self = shift;
    foreach my $item (@_) {
        if (ref($item) eq 'XML::API::Element') {
            carp 'attempt to _add XML::API::Element (private class)';
            return;
        }
        if (ref($item) eq ref($self)) {
            if ($item->{root} == $self->{root}) {
                carp 'attempt to _add object to itself';
                return;
            }
            $item->{parent} = $self->{current};
            $self->{current}->add_content($item->{root});
        }
        else {
            $self->{current}->add_content($item);
        }
    }
}


sub _attrs {
    my $self  = shift;

    if (@_) {
        my $attrs = shift;
        if (!$attrs) {
            croak 'usage: _attrs($hashref)';
        }
        if (ref($attrs) ne 'HASH') {
            croak 'usage: _attrs($hashref)';
        }
        $self->{current}->{attrs} = $attrs;
    }
    return $self->{current}->{attrs};
}

#
# Set Element identifiers
#
sub _set_id {
    my $self = shift;
    my $id   = shift;

    if (!defined($id) or $id eq '') {
        carp '_set_id called without a valid id';
        return;
    }
    if (defined($self->{ids}->{$id})) {
        carp 'id '.$id.' already defined - overwriting';
    }
    $self->{ids}->{$id} = $self->{current};
}

sub _goto {
    my $self = shift;

    if (@_) {
        my $id = shift;
        if (ref($id) eq 'XML::API::Element') {
            $self->{current} = $id;
        }
        elsif (defined($self->{ids}->{$id})) {
                $self->{current} = $self->{ids}->{$id};
        }
        else {
            carp 'unknown/unfound argument to _goto';
        }
    }
    return $self->{current};
}


sub _comment {
    my $self = shift;
    $self->_add("\n<!-- ", @_, " -->");
}


sub _cdata {
    my $self = shift;
    $self->_add("\n<![CDATA[", @_, " ]]>");
}


sub _fast_string {
    my $self = shift;
    my $start = '';

    if ($self->{root}->name eq $self->_root_element) {
        $start = '<?xml version="1.0" encoding="ISO-8859-1"?>' .
                 $self->_doctype;
    }
    return $start . $self->{root}->fast_string();
}

sub _as_string {
    my $self  = shift;
    my $start = '';

    if ($self->{root}->name eq $self->_root_element) {
        $start = '<?xml version="1.0" encoding="ISO-8859-1"?>' . "\n" .
                 $self->_doctype;
    }
    return $start . $self->{root}->as_string();
}


sub _print {
    my $self = shift;
    print $self->_as_string(), "\n";
}


sub _freeze {
    my $self = shift;
    return freeze($self);
}



#
# We must specify the DESTROY function explicitly otherwise our AUTOLOAD
# function gets called at object death.
#
DESTROY {};

1;

__END__

=head1 NAME

XML::API - Perl extension for creating XML documents

=head1 SYNOPSIS

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

=head2 $x->_parse($content)

Adds content to the current element, but will parse it for xml elements
and add them as method calls if the XML::API::<doctype> class supports
this method.

=head2 $x->_current( )

Returns a reference (private data type) to the current element. Can
be used in the _goto method to get back to the current element in the
future.

=head2 $x->_set_id($id)

Set an identifier for the current element. You can then use the value
of $id in the _goto() method.

=head2 $x->_goto($id)

Change the 'current' element. $id is a value which has been previously
used in the _set_id() method, or the return value of a _current() call.

This is useful if you create the basic structure of your document, but
then later want to go back and modify it or fill in the details.

=head2 $x->_attrs( )

Allows you to get/set the attributes of the current element. Accepts
and returns and hashref.

=head2 $x->_comment($comment)

Is a shortcut for $x->_add('\n<!--', $content, '-->')

=head2 $x->_cdata( )

Is a shortcut for $x->_add("\n<![CDATA[", @_, " ]]>");

=head2 $x->_as_string( )

Returns the rendered version of the XML document.

=head2 $x->_fast_string( )

Returns the rendered version of the XML document without newlines or
indentation.

=head2 $x->_print( )

A shortcut for "print $x->_as_string()"

=head1 STORAGE

The Perl Storage module can be used for persistant storage and retrieval
of XML::XHTML objects with the following shortcuts.

=head2 $x->_freeze( )

Returns the (binary) frozen form of itself. Basically a shortcut for
"use Storable; return Storable::freeze($x);".

=head2 _thaw($data)

This is a class subroutine (ie not an object method) which is basically
a shortcut for "use Storable; return thaw($data);". Should 'unfreeze' the
binary $data and return the reconstucted object.

=head1 SEE ALSO

B<XML::API> was written for the Rekudos framework:  http://rekudos.net/

=head1 AUTHOR

Mark Lawrence E<lt>nomad@null.netE<gt>

A small request: if you use this module I would appreciate hearing about it.

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2004,2005 Mark Lawrence <nomad@null.net>

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

=cut


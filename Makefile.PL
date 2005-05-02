use 5.006;
use inc::Module::Install;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

my $version = '0.03';
my $name    = 'XML::API';
my $fname   = "XML-API-$version";

my $prereqs = {
    'Test::More'        => 0,
};

sub MY::postamble { "

changes:
	echo 'Changelog for Perl extension $name' > $$
	echo '' >> $$
	-darcs changes >> $$ && mv $$ Changes
	rm -f $$
                                
deb: changes
	rm -f $fname.tar.gz
	\$(MAKE) dist
	tar zxvf $fname.tar.gz
	cd $fname && dpkg-buildpackage -b -rfakeroot -tc
	rm -rf $fname*
                                                                        
";
}

WriteMakefile(
    NAME              => $name,
    VERSION           => $version,
    PREREQ_PM         => $prereqs,
    ABSTRACT          => 'turn an XML Schema Definition into an object API',
    AUTHOR            => 'Mark Lawrence <nomad@null.net>',
);

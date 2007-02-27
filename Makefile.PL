use 5.006;
use inc::Module::Install;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

my $version = '0.11';
my $name    = 'XML::API';
my $fname   = "XML-API-$version";

my $prereqs = {
    'Test::More'         => 0,
    'Tree::Simple'       => 1.17,
    'XML::Parser::Expat' => 0,
};

sub MY::postamble { "

changes:
	echo 'Changelog for Perl extension $name' > $$
	echo '' >> $$
	-darcs changes >> $$ && mv $$ Changes
	rm -f $$
                                
deb: changes
	(head -1 debian/changelog | grep $version) || exit 1
	rm -f $fname.tar.gz *.deb *.changes
	-chmod 755 debian/rules
	\$(MAKE) dist
	tar zxvf $fname.tar.gz
	cd $fname && dpkg-buildpackage -b -rfakeroot -tc

deba:
	sudo cp *.deb *.changes /var/lib/debarchiver/incoming
	sudo debarchiver -so

tgz:
	rm -f XML-API.tgz
	ln -s $fname.tar.gz XML-API.tgz

";
}

WriteMakefile(
    NAME              => $name,
    VERSION           => $version,
    PREREQ_PM         => $prereqs,
    ABSTRACT          => 'Perl extension for creating XML documents',
    AUTHOR            => 'Mark Lawrence <nomad@null.net>',
);

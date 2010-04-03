#!/usr/bin/perl

use feature qw/switch/;
use strict;
use warnings;
use Cwd;
use File::Basename;
use File::Find;
use YAML::Tiny;

our $CONFIG = YAML::Tiny->read('./dperl.yml');
our $NAME = $CONFIG->[0]{'name'} || basename getcwd;
our $TOP_MODULE;
our $VERSION;

my $version_re = qr/\d+ \. \w+/x;

name_to_module();

die "'$NAME' is not a valid repo name\n" unless $TOP_MODULE;
die "require './lib' directory\n" unless -d './lib';
die "require './t' directory\n" unless -d './t';

if(@ARGV ~~ /-+update/) {
    clean();
    print "* Create/update t/00-load.t and t/99-pod*t\n";
    t_compile();
    t_pod();
    changes();
    print "* Create/update README\n";
    readme();
    print "* Repository got updated\n";
}
elsif(@ARGV ~~ /-+build/) {
    clean();
    print "* Create/update t/00-load.t and t/99-pod*t\n";
    t_compile();
    t_pod();
    print "* Update Changes\n";
    changes('update');
    print "* Create/update README\n";
    readme();
    print "* Build $NAME\n";
    makefile();
    manifest();
    meta_yml();
    dist();
    print "* $NAME got built\n";
}
elsif(@ARGV ~~ /-+release/) {
    release();
}
elsif(@ARGV ~~ /-+test/) {
    clean();
    t_compile();
    t_pod();
    makefile();
    test();
}
elsif(@ARGV ~~ /-+clean/) {
    clean();
    print "$NAME got cleaned\n";
}
elsif(@ARGV ~~ /dperl.yml/) {
    print <<"DPERL";
# Example dperl.yml:
---
requires:
  namespace::autoclean: 0.02
  Catalyst: 5.8
test_requires:
  Test::More: 0.9
resources:
  bugtracker: http://rt.cpan.org/NoAuth/Bugs.html?Dist=Foo-Bar
  homepage: foo.com
  repository: http://github.com/wall-e/foo-bar

DPERL
    exit 1;
}
else {
    print <<"HELP";
Usage $0 [option]

 -update
  * Create/update t/00-load.t and t/99-pod*t
  * Create/update README

 -build
  * Same as -update
  * Update Changes with release date
  * Create Makefile.PL, MANIFEST and META.yml
  * Create a distribution (.tar.gz)

 -release
  * Will create a new git commit and tag

 -test
  * Will test the project

 -clean
  * Will remove files and directories

 -dperl.yml
  * Prints an example dperl.yml config file

HELP
    exit 1;
}

exit 0;

#=============================================================================
sub name_to_module {
    my $check_dir = sub {
        opendir my $DH, $_[0] or die $!;
    };

    my @path = split /-/, $NAME;
    my $path = 'lib';
    my $file;

    $path[-1] .= ".pm";

    for my $p (@path) {
        opendir my $DH, $path or die $!;
        for my $f (readdir $DH) {
            if(lc $f eq lc $p) {
                $path = "$path/$f";
                last;
            }
        }
    }
    
    unless(-f $path) {
        die "'$path' is not a file\n";
    }

    $NAME = $path;
    $NAME =~ s,lib/,,;
    $NAME =~ s,\.pm,,;
    $NAME =~ s,/,-,g;
    $TOP_MODULE = $path;
}

sub release {
    my $commit_msg;

    open my $CHANGES, '<', 'Changes' or die $!;

    while(<$CHANGES>) {
        if($commit_msg) {
            if(/^$/) {
                last;
            }
            else {
                $commit_msg .= $_;
            }
        }
        elsif(/^($version_re)\s+\w+.*$/) {
            $VERSION = $1;
            $commit_msg = $_;
        }
    }

    unless($VERSION) {
        die "Could not find \$VERSION from Changes\n";
    }
    unless(-e "$NAME-$VERSION.tar.gz") {
        die "Need to run -build first\n";
    }

    system git => commit => -a => -m => $commit_msg;
    system git => tag => $VERSION;
}

sub changes {
    my $date = qx/date/;
    my($changes, $pm);

    chomp $date;

    open my $CHANGES, '+<', 'Changes' or die $!;
    { local $/; $changes = <$CHANGES> };

    if($_[0] and $changes =~ s/\n($version_re)\s*$/{ sprintf "\n%-7s  %s", $1, $date }/em) {
        $VERSION = $1;
    }
    elsif($changes =~ /\n($version_re)\s+/) {
        $VERSION = $1;
    }
    else {
        die "Could not find \$VERSION from Changes\n";
    }

    seek $CHANGES, 0, 0;
    print $CHANGES $changes;

    open my $PM, '+<', $TOP_MODULE or die $!;
    { local $/; $pm = <$PM> };
    $pm =~ s/=head1 VERSION.*?\n=/=head1 VERSION\n\n$VERSION\n\n=/s;
    $pm =~ s/\$VERSION\s*=.*$/\$VERSION = '$VERSION';/m;

    seek $PM, 0, 0;
    print $PM $pm;
}

sub readme {
    system "perldoc -tT $TOP_MODULE > README";
}

sub clean {
    system "make clean 2>/dev/null";
    system "rm -r $NAME* META.yml MANIFEST* Makefile* blib/ inc/ 2>/dev/null";
}

sub test {
    system make => 'test';
}

sub makefile {
    open my $MAKEFILE, '>', 'Makefile.PL' or die $!;
    printf $MAKEFILE "use inc::Module::Install;\n";
    printf $MAKEFILE "name q(%s);\n", $NAME;
    printf $MAKEFILE "all_from q(%s);\n", $TOP_MODULE;

    if(my $req = $CONFIG->[0]{'requires'}) {
        for my $name (sort keys %$req) {
            printf $MAKEFILE "requires q(%s) => %s;\n", $name, $req->{$name} || 0;
        }
    }

    if(my $req = $CONFIG->[0]{'test_requires'}) {
        for my $name (sort keys %$req) {
            printf $MAKEFILE "test_requires q(%s) => %s;\n", $name, $req->{$name} || 0;
        }
    }

    print $MAKEFILE "auto_insall;\n";
    print $MAKEFILE "WriteAll;\n";

    system "perl Makefile.PL";
}

sub manifest {
    open my $SKIP, '>', 'MANIFEST.SKIP' or die $!;
    print $SKIP "$_\n" for qw(
                           ^dperl.yml
                           .git
                           \.old
                           \.swp
                           ~$
                           ^blib/
                           ^Makefile$
                           ^MANIFEST.*
                       ), $NAME;

    system "make manifest" and die "make manifest: $!";
}

sub dist {
    system "rm $NAME* 2>/dev/null";
    system "make dist" and die "make dist: $!";
}

sub meta_yml {
    my $meta = YAML::Tiny->read('META.yml');

    if(my $r = $CONFIG->[0]{'resources'}) {
        for my $k (keys %$r) {
            $meta->[0]{'resources'}{$k} = $r->{$k};
        }
    }

    $meta->write('META.yml');
}

sub t_header {
    return <<'HEADER';
#!/usr/bin/perl
use lib qw(lib);
use Test::More;
HEADER
}

sub t_pod {
    open my $POD_COVERAGE, '>', 't/99-pod-coverage.t' or die $!;
    print $POD_COVERAGE t_header();
    print $POD_COVERAGE <<'TEST';
eval 'use Test::Pod::Coverage; 1' or plan skip_all => 'Test::Pod::Coverage required';
all_pod_coverage_ok();
TEST

    open my $POD, '>', 't/99-pod.t' or die $!;
    print $POD t_header();
    print $POD <<'TEST';
eval 'use Test::Pod; 1' or plan skip_all => 'Test::Pod required';
all_pod_files_ok();
TEST
}

sub t_compile {
    my @modules;

    finddepth(sub {
        return unless($File::Find::name =~ /\.pm$/);
        $File::Find::name =~ s,.pm$,,;
        $File::Find::name =~ s,lib/?,,;
        $File::Find::name =~ s,/,::,g;
        push @modules, $File::Find::name;
    }, 'lib');

    open my $USE_OK, '>', 't/00-load.t' or die $!;

    print $USE_OK t_header();
    printf $USE_OK "plan tests => %i;\n", int @modules;

    for my $module (sort { length $a <=> length $b } @modules) {
        printf $USE_OK "use_ok('%s');\n", $module;
    }

    close $USE_OK;
}

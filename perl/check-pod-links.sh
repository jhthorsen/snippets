#!/bin/sh

ROOT="$PWD/html/lib";

for pod_file in $(find lib/ -type f); do
    out_file=html/$(perl -e'$ARGV[0]=~s/.pm/.html/; print $ARGV[0]' $pod_file);
    out_dir=$(dirname $out_file);

    if [ ! -e $out_file ]; then
        mkdir -p $out_dir
        pod2html --norecurse --htmlroot=$ROOT $pod_file > $out_file;
        echo "Wrote $out_file";
    fi

done

for html_file in $(find html/ -type f); do
    echo "Checking $html_file";
    perl -nle'
        for(/href="(\/.*?\.html)"/) {
            print "> $1" and exit 1 unless -e $1
        }
        for(/href="(\/.*?\.html)#([^"]+)"/) {
            print "> $1" unless -e $1;
            open $FH, "<", $1 or die "$1: $!";
            /name="$2"/ and exit 0 while(<$FH>);
            print "> $1#$2" and exit 1 unless $found;
        }
    ' $html_file
done

rm pod2htmd.tmp;
rm pod2htmi.tmp;

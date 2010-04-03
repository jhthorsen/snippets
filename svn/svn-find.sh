#!/bin/sh

if [ -z $1 ]; then
    echo "Usage:";
    echo "$ svn_find <folder> <filename> <file content>
    echo "Example:";
    echo "$ svn_find . "\.pm" "^use Foo;";
    exit 1;
fi

DIR=$1;
FILE=$2;
CONTENT=$3;

find $DIR | grep -v "\.svn" | grep $FILE | xargs grep $CONTENT;

exit $?
#!/bin/bash
#
# pair-nosplit-one.sh <filename> <cogserver-host> <cogserver-port>
#
# Support script for word-pair counting of pre-split plain-text.
# The file should contain one sentence per line, and words should be
# delimited by whitespace.
#
# Submit that one file, via perl script, to the parser.
# When done, move the file over to a `submitted-articles` directory.
#
# Example usage:
#    ./pair-nosplit-one.sh en Barbara localhost 17001
#

# Set up assorted constants needed to run.
filename="$1"
# coghost="localhost"
# cogport=17002
coghost="$2"
cogport=$3

splitdir=split-articles
subdir=submitted-articles
observe="observe-text"

# Punt if the cogserver has crashed. Use netcat to ping it.
haveping=`echo foo | nc $coghost $cogport`
if [[ $? -ne 0 ]] ; then
	exit 1
fi

# Split the filename into two parts
base=`echo $filename | cut -d \/ -f 1`
rest=`echo $filename | cut -d \/ -f 2-6`

echo "Pair-count processing file >>>$rest<<<"

# Create directories if missing
mkdir -p $(dirname "$splitdir/$rest")
mkdir -p $(dirname "$subdir/$rest")

# Move article to temp directory, while processing.
cp "$filename" "$splitdir/$rest"

# Submit the pre-split article
cat "$splitdir/$rest" | ./submit-one.pl $coghost $cogport $observe

# Punt if the cogserver has crashed (second test,
# before doing the mv and rm below)
haveping=`echo foo | nc $coghost $cogport`
if [[ $? -ne 0 ]] ; then
	exit 1
fi

# Move article to the done-queue
mv "$splitdir/$rest" "$subdir/$rest"
rm "$base/$rest"

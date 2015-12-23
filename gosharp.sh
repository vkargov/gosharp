#!/usr/bin/env bash

# Just a prototype currently...

# TODO
# Make sure this works both on OSX and Linux (and MinGW?), without the need of any additional software.

set -e

set -vx

TESTPROJ=gosharp
TESTDIR="$PWD/go/src/$TESTPROJ"
CILDIR="$PWD/cil"
GOPATH="$PWD/go"

# Create infrastructure
if [ ! -e go ]; then
    mkdir -p "$GOPATH/src"
fi
if [ ! -e tardisgo ]; then
    go install github.com/tardisgo/tardisgo
fi
if [ ! -e "$CILDIR" ]; then
    mkdir -p "$CILDIR"
fi

# Paranoia check for $]TESTDIR, since we will be calling rm -rf on it
if [ ${#TESTDIR} -le 5 ]; then
    echo "A dodgy error has occurred."
    exit 1
fi

# Prepare the directory for building CIL
rm -rf "$TESTDIR"

# Golang's Go1 suite
# It is a special case since it has its own hard-coded driver (which is sadly not very
# straightforward to adjust for this task) and the tests do not abide by the standard Go path
# structure (oh irony)
if [ ! -e golang ]; then
    git clone https://github.com/golang/go golang
fi
GOSRC="$GOPATH/src"
GO1PATH="$GOSRC/go1"

# Fill the Go1 package with test files
# Rename files so that our non-test run would notice them
# cd "$PWD/golang/test/bench/go1"
# for f in *; do
#     # ln -sf "$PWD/$f" "$TESTDIR/$(sed 's/_test.go/_extest.go/' <<<$f)"
#     cp "$PWD/$f" "$TESTDIR/$(sed 's/_test.go/_extest.go/' <<<$f)"
# done
# cd -

ln -hsf "$PWD/golang/test/bench/go1" "$GO1PATH"
for d in "$PWD/golang/src/"*; do
    if [ -d "$d" ]; then
	ln -hsf "$d" "$GOSRC"
    fi
done

# "Normal" tests.
# Should come in the standard package structure, which could be included straight away by our driver.
# stub

# Create a separate executable for each test in the suite
for BENCH_FILE in ~/work/gosharp/golang/test/bench/go1/*; do
    if [ -d "$BENCH_FILE" ]; then continue; fi
    for BENCH_NAME in $(gsed -nE 's/^\W*func (Benchmark[^a-z]\w*).*/\1/p' "$BENCH_FILE"); do
	echo -n "Generating test for ${BENCH_NAME} located at ${BENCH_FILE}... "
	mkdir "$TESTDIR"
	cat <<< "package main

import (
       \"testing\"
)

func main() {
     b := testing.B {N: 1}
     $BENCH_NAME(&b)
}
" > "$TESTDIR"/gosharp.go
	cp "$BENCH_FILE" "$TESTDIR"/test.go
	gsed -i 's/package go1/package main/' "$TESTDIR/test.go"
	# go build -o "go/bin/$BENCH_NAME" gosharp
	if false; then
	    # Test run with the standard Go
	    go build -o "./go/bin/$BENCH_NAME" gosharp 
	    "./go/bin/$BENCH_NAME"
	else
	    # Convert to CIL
	    cd "$TESTDIR"
	    "$GOPATH/bin/tardisgo" gosharp # gosharp.go
	    haxe -main tardis.Go -cp tardis -dce full -D uselocalfunctions -cs tardis/go.cs
	    cp ./tardis/go.cs/bin/Go.exe "$CILDIR/$BENCH_NAME"
	    rm -rf "$TESTDIR"
	    cd -
	fi
	echo "OK"
    done
done

#cp golang/test/bench/go1/binarytree_test.go "$TESTDIR/testfunc.go"

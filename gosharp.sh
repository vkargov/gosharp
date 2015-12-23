#!/bin/bash

# Just a prototype currently...

# TODO
# Make sure this works both on OSX and Linux (and MinGW?), without the need of any additional software.

#set -ev
TESTPROJ=gosharp
TESTDIR="go/src/$TESTPROJ"
GOPATH="$PWD/go"

# Create infrastructure

if [ ! -e go ]; then
    mkdir -p "$GOPATH/src"
fi
if [ ! -e tardisgo ]; then
    git clone https://github.com/tardisgo/tardisgo
fi
mkdir -p "$TESTDIR"

# Golang's Go1 suite
# It is a special case since it has its own hard-coded driver (which is sadly not very
# straightforward to adjust for this task) and the tests do not abide by the standard Go path
# structure (oh irony)
if [ ! -e golang ]; then
    git clone https://github.com/golang/go golang
fi
GO1PATH="$GOPATH/src/go1"
ln -Fhs "$PWD/golang/test/bench/go1" "$GO1PATH"

# "Normal" tests.
# Should come in the standard package structure, which could be included straight away by our driver.
# stub

# Create a separate executable for each test in the suite
for BENCH_FILE in ~/work/gosharp/golang/test/bench/go1/*; do
    if [ -d "$BENCH_FILE" ]; then continue; fi
    for BENCH_NAME in $(gsed -nE 's/^\W*func (Benchmark[^a-z]\w*).*/\1/p' "$BENCH_FILE"); do
	echo -n "Generating test for ${BENCH_NAME} located at ${BENCH_FILE}... "
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
	go build gosharp
	./go/bin/test
	echo "OK"
    done
done

#cp golang/test/bench/go1/binarytree_test.go "$TESTDIR/testfunc.go"

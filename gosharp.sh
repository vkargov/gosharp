#!/bin/bash

# Just a prototype currently...

set -ev
TESTPROJ=gosharp
TESTDIR="go/src/$TESTPROJ"
GOPATH="$PWD/go"

# Create infrastructure

if [ ! -e go ]; then
    mkdir "$GOPATH"
fi
if [ ! -e tardisgo ]; then
    git clone https://github.com/tardisgo/tardisgo
fi
mkdir -p "$TESTDIR"
cat <<<'package main

import (
       "testing"
)

func main() {
     b := testing.B {N: 1}
     BenchmarkBinaryTree17(&b)
}' > "$TESTDIR"/gosharp.go

# Build Go1 tests

if [ ! -e golang ]; then
    git clone https://github.com/golang/go golang
fi

cp golang/test/bench/go1/binarytree_test.go "$TESTDIR/testfunc.go"
sed -i '' -e 's/package go1/package main/' "$TESTDIR/testfunc.go"
go build "$TESTPROJ"
./go/bin/test
echo "Yay?"

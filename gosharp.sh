#!/usr/bin/env bash

# Just a prototype currently...

# TODO
# Make sure this works both on OSX and Linux (and MinGW?), without the need of any additional software.

set -e

# set -vx

TESTPROJ=gosharp
TESTDIR="$PWD/go/src/$TESTPROJ"
CILDIR="$PWD/cil"
GOPATH="$PWD/go"
GOSRC="$GOPATH/src"

# Create infrastructure
if [ ! -e go ]; then
    mkdir -p "$GOPATH/src"
fi
if [ ! -e tardisgo ]; then
    TARDIS_PATH="github.com/tardisgo/tardisgo"
    go get "$TARDIS_PATH"
fi
if [ ! -e "$CILDIR" ]; then
    mkdir -p "$CILDIR"
fi

# Paranoia check for $TESTDIR, since we will be calling rm -rf on it
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

# Fill the Go1 package with test files
# Rename files so that our non-test run would notice them
GO1SRC="$PWD/golang/test/bench/go1"
# cd "$GO1SRC"
# for f in *; do
#     # ln -sf "$PWD/$f" "$TESTDIR/$(sed 's/_test.go/_extest.go/' <<<$f)"
#     # cp "$PWD/$f" "$TESTDIR/$(sed 's/_test.go/_extest.go/' <<<$f)"
#     newf="$GO1PATH/$(sed 's/_test.go/_extest.go/' <<<$f)"
#     cp "$f" "$newf"
#     # gsed -ri 's/\b(Benchmark[^a-z]\w+)\b/Ex\1/' "$newf"
# done
# cd -

#ln -hsf "$PWD/golang/test/bench/go1" "$GO1PATH"
# for d in "$PWD/golang/src/"*; do
#     if [ -d "$d" ]; then
# 	ln -hsf "$d" "$GOSRC"
#     fi
# done

# "Normal" tests.
# Should come in the standard package structure, which could be included straight away by our driver.
# stub

# Create a separate executable for each test in the suite
for BENCH_FILE_PATH in "$GO1SRC"/*; do
    BENCH_FILE="$(basename $BENCH_FILE_PATH)"
    if [ -d "$BENCH_FILE" ]; then continue; fi
    for BENCH_NAME in $(gsed -nE 's/^\W*func (Benchmark[^a-z]\w*).*/\1/p' "$BENCH_FILE_PATH"); do	
	echo -n "Generating test for ${BENCH_NAME} located at ${BENCH_FILE}... "

	CILNAME="$CILDIR/$BENCH_NAME.exe"
	if [ -e "$CILNAME" ]; then
	    echo "Exists"
	    continue
	fi
	
	mkdir "$TESTDIR"
	cat <<< "package main

import (
       \"go1\"
       \"testing\"
       \"fmt\"
       \"os\"
)

func main() {
    fmt.Println(\"$BENCH_NAME: a Go test from $BENCH_FILE compiled into CIL.\")
    if len(os.Args) != 1 {
        fmt.Println(\"$Usage:\\n$BENCH_NAME.exe N\\nwhere N is the number of iterations\")
    }									 
    b := testing.B {N: 1}
    go1.${BENCH_NAME}(&b)
}
" > "$TESTDIR"/gosharp.go

	# Recreate go1 dir
	GO1PATH="$GOSRC/go1"
	rm -rf "$GO1PATH"
	mkdir "$GO1PATH"

	# Fill with appropriate tests
	cp "$BENCH_FILE_PATH" "$GO1PATH/$(sed 's/_test.go/_extest.go/' <<<$BENCH_FILE)"
	
	# Manually copy dependencides. DCE in Tardis is nonexistent, so can't keep the whole fat package...
	# Otherwise Haxe will chug for good 10 minutes, and then quit with an "unknown error".
	for t in gob gzip json template; do
	    if [ "$BENCH_FILE" == "${t}_test.go" ]; then
		for f in json jsondata; do
		    cp "${GO1SRC}/${f}_test.go" "${GO1PATH}/${f}_extest.go"
		done
	    fi
	done
	if [ "$BENCH_FILE" == "revcomp_test.go" ]; then
	    cp "${GO1SRC}/fasta_test.go" "${GO1PATH}/fasta_extest.go"
	fi
	if [ "$BENCH_FILE" == "parser_test.go" ]; then
	    cp "${GO1SRC}/parserdata_test.go" "${GO1PATH}/parserdata_extest.go"
	fi
	    
	
	# gsed -i 's/package go1/package main/' "$TESTDIR/test.go"
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
	    sed 's/\\bBenchmark//' <<<$CILNAME
	    cp ./tardis/go.cs/bin/Go.exe "$(sed 's/Benchmark//' <<<$CILNAME)"
	    rm -rf "$TESTDIR"
	    cd -
	fi
	echo "OK"
    done
done

#cp golang/test/bench/go1/binarytree_test.go "$TESTDIR/testfunc.go"

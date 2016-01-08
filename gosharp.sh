#!/usr/bin/env bash

# Just a prototype currently...

# TODO
# Make sure this works both on OSX and Linux (and MinGW?), without the need of any additional software.

#set -e

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
    ITER_COUNT=1
    BENCH_FILE="$(basename $BENCH_FILE_PATH)"
    if [ -d "$BENCH_FILE" ]; then rm "$BENCH_FILE"; fi
    for BENCH_NAME in $(gsed -nE 's/^\W*func (Benchmark[^a-z]\w*).*/\1/p' "$BENCH_FILE_PATH"); do
	TIME=0
	while [ $TIME -lt 10 ]; do # > 10 seconds
	    echo -n "Generating test for ${BENCH_NAME} located at ${BENCH_FILE} with $ITER_COUNT iteration(s)... "

	    CILNAME="$CILDIR/$(sed 's/^Benchmark//' <<<$BENCH_NAME.exe)"
	    # if [ -e "$CILNAME" ]; then
	    # 	echo "Exists"
	    # 	continue
	    # fi
	    
	    mkdir "$TESTDIR"
	    cat <<< "package main

import (
       \"go1\"
       \"testing\"
       \"fmt\"
       \"os\"
)

func err() {
    fmt.Println(\"Usage:\\n$BENCH_NAME.exe N\\nwhere N is the number of iterations\")
    os.Exit(1)
}

func main() {
    fmt.Println(\"$BENCH_NAME: a Go test from $BENCH_FILE compiled into CIL. (iteration count N: $ITER_COUNT)\")

    b := testing.B{N: $ITER_COUNT}
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
		"./go/bin/$BENCH_NAME" 1
	    else
		# Convert to CIL
		pushd "$TESTDIR"
		"$GOPATH/bin/tardisgo" gosharp # gosharp.go
		haxe -main tardis.Go -cp tardis -dce full -D uselocalfunctions,no-compilation -cs tardis/go.cs
		pushd ./tardis/go.cs
		# Replacing public methods with internal could give some gains(?), but it's not as straightforward as this. TODO?
		# find src -type f -exec gsed -Ei '/Equals|GetHashCode|ToString|Message/!s/public/internal/' {} \;
		xbuild /p:TargetFrameworkVersion="v4.0" /p:Configuration=Release Go.csproj /p:AssemblyName="$BENCH_NAME"
		popd
		cp ./tardis/go.cs/bin/Release/"$BENCH_NAME".exe "$CILNAME"
		# exit
		rm -rf "$TESTDIR"
		popd
	    fi

	    # Test run application, measure its execution timecase
	    # TODO: need additional handling for times longer than 59 seconds
	    RAW_TIMES="$(/usr/bin/env time -p gtimeout 20 mono $CILNAME 2>&1)"
	    echo "$RAW_TIMES"
	    TIME="$(sed -nE 's/^real.*[^0-9]([0-9]+)\.([0-9]+)$/\1/p' <<< "$RAW_TIMES")"
	    if [ "z$TIME" == "z" ]; then
	       echo 'Test timed out(?)'.
	       TIME=9001
	       continue
	    fi
            echo t\($ITER_COUNT\) = $TIME
	    ITER_COUNT=$((($ITER_COUNT*2)))
	done
    done
done

#cp golang/test/bench/go1/binarytree_test.go "$TESTDIR/testfunc.go"

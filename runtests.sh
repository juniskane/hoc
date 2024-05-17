#!/bin/sh

HOC=${HOC:=./hoc}

ntests=0
npass=0
nfail=0

got=$(mktemp)
trap 'rm "$got"' EXIT

for exp in ./tests/*.exp; do
    t="$(basename "$exp" .exp)"
    ntests=$((ntests+1))
    printf '%-20s ...' "$t"
    $HOC "./tests/$t" > "$got"
    if [ $? = 0 ] && cmp -s "$got" "$exp"
    then
        npass=$((npass+1))
        printf 'PASS\n'
    else
        nfail=$((nfail+1))
        printf 'FAIL\n'
    fi
done

printf '\n%d tests:\t%d passed\t%d failed\t\n' \
    $ntests $npass $nfail

if [ $nfail -ne 0 ]; then
    exit 1
fi

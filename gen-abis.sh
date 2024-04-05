#!/bin/bash

set -euo pipefail

rm -rf abis
mkdir abis

for i in src/*.sol src/**/*.sol; do
	i="$(basename "$i")"
	name="${i%.sol}"
	jq .abi < "out/$i/$name.json" > "abis/${name}.json"
done

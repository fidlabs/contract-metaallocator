#!/bin/bash

set -euo pipefail
sudo apt-get install lcov

forge clean && forge coverage --report lcov

awk '/TN:/,/SF:test\//{if (!/SF:test\// && !/SF:script/) print; if (/TN:/ && /SF:test\//) exit}' lcov.info > lcon_without_tests.info
branches=$(genhtml lcon_without_tests.info -o report --branch-coverage)

lines_coverage=$(echo "$branches" | awk '/lines/{print $2}' | tr -d '%')
functions_coverage=$(echo "$branches" | awk '/functions/{print $2}' | tr -d '%')
branches_coverage=$(echo "$branches" | awk '/branches/{print $2}' | tr -d '%')
echo "Lines coverage: $lines_coverage%"
echo "Functions coverage: $functions_coverage%"
echo "Branches coverage: $branches%"
if [ "$lines_coverage" == "100.0" ] && [ "$functions_coverage" == "100.0" ] && [ "$branches_coverage" == "100.0" ] ; then
    echo "Coverage is 100% for lines, functions and branches."
else
    echo "Coverage is not 100%."
    exit 1
fi
#!/bin/bash

set -euo pipefail

cd "$(dirname "$0")"/..

forge clean && forge coverage --report lcov

awk '/TN:/,/SF:test\//{if (!/SF:test\// && !/SF:script/) print; if (/TN:/ && /SF:test\//) exit}' lcov.info > lcov_without_tests.info
summary=$(lcov --summary lcov_without_tests.info --rc lcov_branch_coverage=1)

lines_coverage=$(echo "$summary" | awk '/lines/{print $2}')
functions_coverage=$(echo "$summary" | awk '/functions/{print $2}')
branches_coverage=$(echo "$summary" | awk '/branches/{print $2}')
echo "Lines coverage: $lines_coverage"
echo "Functions coverage: $functions_coverage"
echo "Branches coverage: $branches_coverage"
if [ "$lines_coverage" == "100.0%" ] && [ "$functions_coverage" == "100.0%" ] && [ "$branches_coverage" == "100.0%" ] ; then
    echo "Coverage is 100% for lines, functions and branches."
else
    echo "Coverage is not 100%."
    exit 1
fi
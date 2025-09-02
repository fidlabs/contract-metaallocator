#!/bin/bash

set -euo pipefail

cd "$(dirname "$0")"/..

forge clean && forge build && forge coverage --no-match-coverage "(script|test|AllocatorV1|ClientV1)" --report lcov

summary=$(lcov --summary lcov.info --rc branch_coverage=1)

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
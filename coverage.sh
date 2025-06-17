#!/bin/bash

set -euo pipefail

forge clean
forge build
forge coverage --report summary --report lcov
genhtml lcov.info -o report --branch-coverage
xdg-open report/index.html

#!/bin/bash
# Usage: ./missing_programs.sh should_have.pkf_list installed.pkf_list
# Prints the programs from the first list that are missing from the second.

if [ $# -ne 2 ]; then
    echo "Usage: $0 <should_have.pkf_list> <installed.pkf_list>"
    exit 1
fi

should_have="$1"
installed="$2"

# Print missing programs
comm -23 <(sort "$should_have") <(sort "$installed")


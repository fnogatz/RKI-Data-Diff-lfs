#!/bin/bash

TODAY=$(date '+%Y-%m-%d')

function usage {
    echo "Usage: ./csv-sort.sh [OPTIONS] [CSV_FILE]"
    echo
    echo "  Sort the given CSV file."
    echo
    echo "Options:"
    echo
    echo -e "  -s=N, --skip=N\t\tSkip the first N lines of the CSV file (default: 1)"
    echo -e "  --without-metadata\t\tRemove the last metadata columns"
    echo -e "  -h, --help\t\t\tShow this message and exit"
    exit
}

while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -d=*|--date=*)
        DATE="${key#*=}"
        shift
        ;;
        -s=*|--skip=*)
        SKIP="${key#*=}"
        shift
        ;;
        --without-metadata)
        WITHOUT_METADATA=true
        shift
        ;;
        -h|--help)
        usage
        shift
        ;;
        *)
        break
        ;;
    esac
done

SKIPS=${SKIP:-1}

(sed -u $((SKIPS))q ; sort) < "${1:-/dev/stdin}" | \
if [ $WITHOUT_METADATA ]; then awk -v FPAT='[^,]*|"[^"]*"' '{ print $1","$2","$3","$4","$5","$6","$7","$8","$9","$10","$11","$12","$13","$14 }'; else cat; fi

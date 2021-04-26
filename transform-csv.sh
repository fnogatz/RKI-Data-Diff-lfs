#!/bin/bash

TODAY=$(date '+%Y-%m-%d')

function usage {
    echo "Usage: init [OPTIONS] CSV_FILE"
    echo
    echo "  Create the initial, cleaned CSV for SQL import from a single RKI CSV dump."
    echo
    echo "Options:"
    echo
    echo -e "  -s=N, --skip=N\t\tSkip the first N lines of the CSV file (default: 1)"
    echo -e "  -d=DATE, --date=DATE\t\tUse given date as 'GueltigAb' (default: $TODAY)"
    echo -e "  -h, --help\t\t\tShow this message and exit"
    exit
}

if [[ $# -lt 1 ]]; then
    usage
fi

while [[ $# -gt 1 ]]; do
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
        -h|--help)
        usage
        shift
        ;;
        *)
        usage
        shift
        ;;
    esac
done

SKIPS=${SKIP:-1}
GUELTIGAB=${DATE:-$TODAY}
CSV=$1

awk -v FPAT='[^,]*|"[^"]*"' -v gueltigab="$GUELTIGAB" '{
    sub(/ .*/, "", $9);
    gsub(/\//, "-", $9);
    sub(/ .*/, "", $14);
    gsub(/\//, "-", $14);
    gsub(/\//, "-", gueltigab);
    print $2","$10","$9","$5","$6","$12","$13","$15","$7","$8","$16","$14","$17","$18","gueltigab",\\N"
}' $CSV | tail -n +$((SKIPS+1)) | sort

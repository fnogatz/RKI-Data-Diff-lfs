#!/bin/bash

TODAY=$(date '+%Y-%m-%d')

function usage {
    echo "Usage: ./csv-transform.sh [OPTIONS] [CSV_FILE]"
    echo
    echo "  Create the initial, cleaned CSV for SQL import from a single RKI CSV dump."
    echo
    echo "Options:"
    echo
    echo -e "  -d=DATE, --date=DATE\t\tUse given date as 'GueltigAb' (default: $TODAY)"
    echo -e "  --without-metadata\t\tDo not add the last metadata columns"
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

GUELTIGAB=${DATE:-$TODAY}

awk -v FPAT='[^,]*|"[^"]*"' -v gueltigab="$GUELTIGAB" -v without_metadata="$WITHOUT_METADATA" '{
    if (NR==1) {
        if (without_metadata=="true") {
            print $2","$10","$9","$5","$6","$12","$13","$15","$7","$8","$16","$14","$17","$18;
        } else {
            print $2","$10","$9","$5","$6","$12","$13","$15","$7","$8","$16","$14","$17","$18",GueltigAb,GueltigBis,DFID";
        }
    } else {
        sub(/ .*/, "", $9);
        gsub(/\//, "-", $9);
        sub(/ .*/, "", $14);
        gsub(/\//, "-", $14);
        if (without_metadata=="true") {
            print $2","$10","$9","$5","$6","$12","$13","$15","$7","$8","$16","$14","$17","$18;
        } else {
            gsub(/\//, "-", gueltigab);
            dfid=sprintf("%s%07d", gueltigab, $1);
            gsub(/-/, "", dfid);
            print $2","$10","$9","$5","$6","$12","$13","$15","$7","$8","$16","$14","$17","$18","gueltigab",\\N,"dfid;
        }
    }
}' < "${1:-/dev/stdin}"

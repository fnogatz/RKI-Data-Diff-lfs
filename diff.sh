#!/bin/bash

function usage {
    echo "Usage: diff [OPTIONS] OLD_CSV NEW_CSV"
    echo
    echo "  Compare two CSV dumps from RKI to get the changed rows as patch file."
    echo
    echo "Options:"
    echo
    echo -e "  -s=N, --skip=N\t\tSkip the first N lines of each CSV file (default: 1)"
    echo -e "  -h, --help\t\t\tShow this message and exit"
    exit
}

if [[ $# -lt 2 ]]; then
    usage
fi

SKEY=1

while [[ $# -gt 2 ]]; do
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
OLD_CSV=$1
NEW_CSV=$2

diff \
    <(awk -v FPAT='[^,]*|"[^"]*"' '{
        sub(/ .*/, "", $9);
        gsub(/\//, "-", $9);
        sub(/ .*/, "", $14);
        gsub(/\//, "-", $14);
        neuerfall=$12;
        if ($12 == 1) {
            neuerfall=0;
        }
        neuertodesfall=$13;
        if ($13 == 1) {
            neuertodesfall=0;
        }
        neugenesen=$15;
        if ($15 == 1) {
            neugenesen=0;
        }
        print $2","$10","$9","$5","$6","neuerfall","neuertodesfall","neugenesen","$7","$8","$16","$14","$17","$18
    }' $OLD_CSV | tail -n +$((SKIPS+1)) | sort) \
    <(awk -v FPAT='[^,]*|"[^"]*"' '{
        sub(/ .*/, "", $9);
        gsub(/\//, "-", $9);
        sub(/ .*/, "", $14);
        gsub(/\//, "-", $14);
        print $2","$10","$9","$5","$6","$12","$13","$15","$7","$8","$16","$14","$17","$18
    }' $NEW_CSV | tail -n +$((SKIPS+1)) | sort)

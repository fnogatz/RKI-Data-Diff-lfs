#!/bin/bash

TODAY=$(date '+%Y-%m-%d')
DEFAULT_COLUMNS="IdBundesland,IdLandkreis,Meldedatum,Altersgruppe,Geschlecht,NeuerFall,NeuerTodesfall,NeuGenesen,AnzahlFall,AnzahlTodesfall,AnzahlGenesen,Refdatum,IstErkrankungsbeginn,Altersgruppe2"

function usage {
    echo "Usage: ./csv-transform.sh [OPTIONS] [CSV_FILE]"
    echo
    echo "  Create the initial, cleaned CSV for SQL import from a single RKI CSV dump."
    echo
    echo "Options:"
    echo
    echo -e "  -d=DATE, --date=DATE\t\tUse given date as 'GueltigAb' (default: $TODAY)"
    echo -e "  -c=COLUMNS, --columns=COLUMNS\t\tUse these columns (default: $DEFAULT_COLUMNS)"
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
        -c=*|--columns=*)
        COLS="${key#*=}"
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
COLUMNS=${COLS:-$DEFAULT_COLUMNS}

if [[ -n "$1" ]]; then
    # check encoding (only if filename given)
    encoding=$(file -i "$1" | cut -f 2 -d";" | cut -f 2 -d=)
    case $encoding in
        iso-8859-1)
        iconv -f iso8859-1 -t utf-8 "$1" > "$1.utf8"
        mv "$1.utf8" "$1"
        ;;
    esac
fi

# we need to remove possible BOMs
sed '1s/^\xEF\xBB\xBF//;s/\r//' < "${1:-/dev/stdin}" | \
awk -F, -v FPAT='[^,]*|"[^"]*"' -v gueltigab="$GUELTIGAB" -v without_metadata="$WITHOUT_METADATA" -v columns="$COLUMNS" -f csv-transform.awk

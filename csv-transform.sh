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

# we need to remove possible BOMs
sed '1s/^\xEF\xBB\xBF//;s/\r//' < "${1:-/dev/stdin}" | \
awk -F, -v FPAT='[^,]*|"[^"]*"' -v gueltigab="$GUELTIGAB" -v without_metadata="$WITHOUT_METADATA" -v columns="$COLUMNS" '
{
    if (NR==1) {
        split(columns,cols,",");
        for(i=1; i<=NF; i++) {
            cell[$i]=i;
        }
        if (without_metadata!="true") {
            columns=columns",GueltigAb,GueltigBis,DFID";
        }
        print columns;
    } else {
        if (cell["Meldedatum"] > 0) {
            if ($cell["Meldedatum"] ~ /^[0-9]{13}$/) {
                # UNIX timestamp in milliseconds
                $cell["Meldedatum"]=strftime("%Y-%m-%d",substr($cell["Meldedatum"],1,10));
            } else {
                sub(/ .*/, "", $cell["Meldedatum"]);
                gsub(/\//, "-", $cell["Meldedatum"]);
                $cell["Meldedatum"]=substr($cell["Meldedatum"],1,10);
            }
        }
        if (cell["Refdatum"] > 0) {
            if ($cell["Refdatum"] ~ /^[0-9]{13}$/) {
                # UNIX timestamp in milliseconds
                $cell["Refdatum"]=strftime("%Y-%m-%d",substr($cell["Refdatum"],1,10));
            } else {
                sub(/ .*/, "", $cell["Refdatum"]);
                gsub(/\//, "-", $cell["Refdatum"]);
                $cell["Refdatum"]=substr($cell["Refdatum"],1,10);
            }
        }
        row="";
        comma="";

        for(i in cols) {
            column=cols[i];
            ref=cell[column];
            if (ref > 0) {
                row=row comma $ref;
            } else {
                row=row comma "\\N";
            }
            comma=",";
        }

        if (without_metadata!="true") {
            gsub(/\//, "-", gueltigab);
            dfid=sprintf("%s%07d", gueltigab, NR-1);
            gsub(/-/, "", dfid);
            row=row","gueltigab",\\N,"dfid;
        }
        print row;
    }
}'

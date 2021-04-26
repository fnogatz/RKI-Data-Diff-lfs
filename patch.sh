#!/bin/bash

TODAY=$(date '+%Y-%m-%d')

function usage {
    echo "Usage: patch [OPTIONS] [FILE]"
    echo
    echo "  Generate SQL-commands from patch file provided via file or stdin."
    echo
    echo "Options:"
    echo
    echo -e "  -d=DATE, --date=DATE\t\tUse given date as reference for GueltigAb and GueltigBis (default: $TODAY)"
    echo -e "  -t=TABLE, --table=TABLE\t\tUse this SQL table name (default: rki_csv)"
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
        -t=*|--table=*)
        TABLE_NAME="${key#*=}"
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

DELIMITER=','
TABLE=${TABLE_NAME:-'rki_csv'}
REF_TODAY=${DATE:-$TODAY}
REF_YESTERDAY=$(date -d @$(( $(date -d $REF_TODAY +"%s") - 24*3600)) +"%Y-%m-%d")

COLUMN_NAMES="IdBundesland,IdLandkreis,Meldedatum,Altersgruppe,Geschlecht,NeuerFall,NeuerTodesfall,NeuGenesen,AnzahlFall,AnzahlTodesfall,AnzahlGenesen,Refdatum,IstErkrankungsbeginn,Altersgruppe2"
# get options as list
IFS=',' read -ra COLS <<< "$COLUMN_NAMES"

section=1
rownumber=1
in_buffer=()
block_rowa_number=1

# read in patch
while read line
do
    # diff header
    if [[ $line =~ ^diff\s-arN ]]; then
        continue
    fi

    # mode header
    if [[ $line =~ ^[0-9]+(,[0-9]+)?[adc][0-9]+(,[0-9]+)?$ ]]; then
        block=$line
        if [[ $mode == "c" ]]; then
            # there could possibly be open deletions of the previous change
            while [[ $block_rowa_number -le ${#in_buffer[@]} ]]; do
                # create deletion
                where=" "
                where_no=1

                for pk_ix in "${!COLS[@]}"; do
                    if [[ ${COLS[$pk_ix]} == "NeuerFall" ]]; then
                        continue;
                    fi
                    if [[ ${COLS[$pk_ix]} == "NeuerTodesfall" ]]; then
                        continue;
                    fi
                    if [[ ${COLS[$pk_ix]} == "NeuGenesen" ]]; then
                        continue;
                    fi

                    if [[ $where_no -gt 1 ]]; then
                        # add leading conjunction
                        where="$where AND "
                    fi

                    where="$where${COLS[$pk_ix]}=\"${rowb[$pk_ix]}\""
                    ((where_no++))
                done
                where="$where AND GueltigBis IS NULL"

#                echo "UPDATE $TABLE SET GueltigBis='$REF_YESTERDAY' WHERE$where LIMIT 1; -- $block"
                ((block_rowa_number++))
            done
        fi

        mode=${line//[^acd]/}  # either a=addition, c=change or d=deletion
        section=1
        rownumber=1
        block_rowa_number=1
        in_buffer=()

        continue
    fi

    # diff section
    if [[ $line == "---" ]]; then
        section=2
        block_rownumber=1
        continue
    fi

    # process line
    row=${line#[<>] }  # remove leading "> "
    row=${row%%[[:space:]]}  # remove trailing spaces
    IFS="$DELIMITER" read -ra rowb <<< "$row"

    # addition
    if [[ ($mode == "a" && $section -eq 1) || ($mode == "c" && $section -eq 2) ]]; then
        values=""
        value_no=1

        for pk_ix in "${!COLS[@]}"; do
            if [[ $value_no -gt 1 ]]; then
                # add leading comma
                values="$values,"
            fi

            values="$values\"${rowb[$pk_ix]}\""
            ((value_no++))
        done

        echo "INSERT INTO $TABLE VALUES ($values,\"$REF_TODAY\",NULL); -- $block"
    fi

    # deletion
    if [[ ($mode == "d" || $mode == "c") && $section -eq 1 ]]; then
        where=" "
        where_no=1

        for pk_ix in "${!COLS[@]}"; do
            if [[ ${COLS[$pk_ix]} == "NeuerFall" ]]; then
                continue;
            fi
            if [[ ${COLS[$pk_ix]} == "NeuerTodesfall" ]]; then
                continue;
            fi
            if [[ ${COLS[$pk_ix]} == "NeuGenesen" ]]; then
                continue;
            fi

            if [[ $where_no -gt 1 ]]; then
                # add leading conjunction
                where="$where AND "
            fi

            where="$where${COLS[$pk_ix]}=\"${rowb[$pk_ix]}\""
            ((where_no++))
        done
        where="$where AND GueltigBis IS NULL"

        echo "UPDATE $TABLE SET GueltigBis='$REF_YESTERDAY' WHERE$where LIMIT 1; -- $block"
    fi

    ((rownumber++))
done < "${1:-/dev/stdin}"

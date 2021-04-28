#!/bin/bash

TODAY=$(date '+%Y-%m-%d')

function usage {
    echo "Usage: patch [OPTIONS] OLD_CSV NEW_CSV"
    echo
    echo "  Generate SQL-commands from two CSV dumps."
    echo
    echo "Options:"
    echo
    echo -e "  -t=TABLE, --table=TABLE\t\tUse this SQL table name (default: rki_csv)"
    echo -e "  -h, --help\t\t\tShow this message and exit"
    exit
}

while [[ $# -gt 2 ]]; do
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

if [[ $# -lt 2 ]]; then
    usage
fi

TABLE=${TABLE_NAME:-'rki_csv'}

exec 3<"$1"
exec 4<"$2"

read row1 <&3 && read row2 <&4 # omit very first line

# read in and preprocess second line
read row1 <&3
read row2 <&4
data1=${row1::-29}
metadata1=${row1: -28}
data2=${row2::-29}
metadata2=${row2: -28}

# store today's date from file2
dfid=${row2: -15}
yyyymmdd="${dfid:0:4}-${dfid:4:2}-${dfid:6:2}"
REF_TODAY=$(date -d @$(date -d $yyyymmdd +"%s") +"%Y-%m-%d")
REF_YESTERDAY=$(date -d @$(( $(date -d $yyyymmdd +"%s") - 24*3600)) +"%Y-%m-%d")

echo "INSERT INTO $TABLE VALUES"

comma="    "
function addition {
    echo -n "$comma"
    echo -n "(\"$1" | sed 's/,/","/g; s/"N"/NULL/'
    echo "\")"
    comma="  , "
}

removals=()
function removal {
    dfid=${1: -15}
    removals+=("$dfid")
}

# loop through all lines
while [[ -n "$data1" || -n "$data2" ]]
do
    if [[ "$data1" == "$data2" ]]; then
        if read row1 <&3; then 
            data1=${row1::-29}
            metadata1=${row1: -28}
        else
            data1=""
        fi
        if read row2 <&4; then 
            data2=${row2::-29}
            metadata2=${row2: -28}
        else
            data2=""
        fi

    elif [[ "$data1" > "$data2" ]]; then
        # new line detected

        if [[ -n "$data2" ]]; then
            # addition of data2
            addition "$row2"

            if read row2 <&4; then 
                data2=${row2::-29}
                metadata2=${row2: -28}
            else
                data2=""
            fi
        else
            # removal of data1, since file2 ended before
            removal "$row1"

            # continue with the rest of file1
            if read row1 <&3; then 
                data1=${row1::-29}
                metadata1=${row1: -28}
            else
                data1=""
            fi
        fi

    elif [[ "$data2" > "$data1" ]]; then
        # deleted line detected

        if [[ -n "$data1" ]]; then
            # removal of data1
            removal "$row1"

            if read row1 <&3; then 
                data1=${row1::-29}
                metadata1=${row1: -28}
            else
                data1=""
            fi
        else
            # addition of data2, since file1 ended before
            addition "$row2"

            # continue with the rest of file2
            if read row2 <&4; then 
                data2=${row2::-29}
                metadata2=${row2: -28}
            else
                data2=""
            fi
        fi
    fi
done

# end previously started INSERT query
echo ";"

# create SQL query for removals
comma="    "
echo "UPDATE $TABLE SET GueltigBis='$REF_YESTERDAY' WHERE DFID IN ("
for removal in ${removals[@]}
do
    echo -n "$comma"
    echo "$removal"
    comma="  , "
done
echo ");"

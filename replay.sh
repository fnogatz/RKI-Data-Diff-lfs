#!/bin/bash

export LC_NUMERIC="en_US.UTF-8"

STARTDATE_DEFAULT="2020-03-21"
TODAY=$(date '+%Y-%m-%d')

function usage {
    echo "Usage: ./replay.sh [OPTIONS] MYSQL_DEFAULTS_FILE"
    echo
    echo "  Create the SQL query to dump data in the same form as a cleaned CSV."
    echo
    echo "Options:"
    echo
    echo -e "  --start=DATE\t\tUse given date as start (default: $STARTDATE_DEFAULT)"
    echo -e "  --end=DATE\t\tUse given date as end (default: $TODAY)"
    echo -e "  -d=DIR, --dir=DIR\t\tUse this directory for temporary files (default: /tmp/...)"
    echo -e "  -t=TABLE, --table=TABLE\t\tUse this SQL table name (default: rki_csv)"
    echo -e "  -c, --continue\t\tStart with update phase instead of initialisation"
    echo -e "  -h, --help\t\t\tShow this message and exit"
    exit
}

while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        --start=*)
        DATE_A="${key#*=}"
        shift
        ;;
        --end=*)
        DATE_B="${key#*=}"
        shift
        ;;
        -d=*|--dir=*)
        TMP_DIR_USER="${key#*=}"
        shift
        ;;
        -t=*|--table=*)
        TABLE_NAME="${key#*=}"
        shift
        ;;
        -c|--continue)
        CONTINUE=true
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

if [[ $# -lt 1 ]]; then
    usage
fi

MYSQL_DEFAULTS_FILE="$1"
DATE_FROM=${DATE_A:-$STARTDATE_DEFAULT}
DATE_TO=${DATE_B:-$TODAY}
TABLE=${TABLE_NAME:-'rki_csv'}

if [[ -z $TMP_DIR_USER ]]; then
    TMP_DIR=`mktemp -d -p /tmp`
else
    TMP_DIR="$TMP_DIR_USER"
fi

function round {
    n=$(printf "%.${1}g" "$2")
    if [ "$n" != "${n#*e}" ]
    then
        f="${n##*e-}"
        test "$n" = "$f" && f= || f=$(( ${f#0}+$1-1 ))
        printf "%0.${f}f" "$n"
    else
        printf "%s" "$n"
    fi
}

date="$DATE_FROM"

if [[ -z "$CONTINUE" ]]; then
    DATABASE=$(sed -n 's/^database=\([^ ]\+\).*/\1/p' "$MYSQL_DEFAULTS_FILE")
    DUMP_PATH="$TMP_DIR/$TABLE.sql.gz"
    echo "# Create mysqldump in $DUMP_PATH and empty table"
    mysqldump --defaults-extra-file="$MYSQL_DEFAULTS_FILE" "$DATABASE" "$TABLE" | gzip > "$DUMP_PATH"
    echo "DELETE FROM $TABLE;" | mysql --defaults-extra-file="$MYSQL_DEFAULTS_FILE"

    START=$(date +%s.%N)
    echo "# START for $date: table initialisation"
    wget -q "https://github.com/micb25/RKI_COVID19_DATA/raw/master/RKI_COVID19_$date.csv.gz" -O "$TMP_DIR/RKI_COVID19.csv.gz"
    gzip -d -f "$TMP_DIR/RKI_COVID19.csv.gz"
    ./csv-transform.sh --date="$date" "$TMP_DIR/RKI_COVID19.csv" | ./csv-sort.sh > "$TMP_DIR/1-init.csv"
    echo "LOAD DATA LOCAL INFILE '$TMP_DIR/1-init.csv' INTO TABLE $TABLE CHARACTER SET UTF8 FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '\"' IGNORE 1 LINES;" | mysql --defaults-extra-file="$MYSQL_DEFAULTS_FILE"

    END=$(date +%s.%N)
    DIFF=$(round 1 "$(echo "$END - $START" | bc)")
    echo "# Full import for $date (took $DIFF seconds)"
    date=$(date -I -d "$date + 1 day")
fi

while [[ ! "$date" > "$DATE_TO" ]]; do 
    START=$(date +%s.%N)
    wget -q "https://github.com/micb25/RKI_COVID19_DATA/raw/master/RKI_COVID19_$date.csv.gz" -O "$TMP_DIR/RKI_COVID19.csv.gz"
    gzip -d -f "$TMP_DIR/RKI_COVID19.csv.gz"

    lines=$(wc -l "$TMP_DIR/RKI_COVID19.csv" | sed 's/ .*$/ /g')
    ./csv-transform.sh --date="$date" "$TMP_DIR/RKI_COVID19.csv" | ./csv-sort.sh > "$TMP_DIR/1-init.csv"
    rm -f "$TMP_DIR/2-tmp.csv"
    ./create-sql-query.sh --known-before --date="$date" "$TMP_DIR/2-tmp.csv" | mysql --defaults-extra-file="$MYSQL_DEFAULTS_FILE"
    cat "$TMP_DIR/2-tmp.csv" | ./csv-sort.sh > "$TMP_DIR/3-predump.csv"
    ./patch.sh "$TMP_DIR/3-predump.csv" "$TMP_DIR/1-init.csv" > "$TMP_DIR/4-patch.sql"
    changes=$(tail -n1 "$TMP_DIR/4-patch.sql")
    cat "$TMP_DIR/4-patch.sql" | mysql --defaults-extra-file="$MYSQL_DEFAULTS_FILE"

    END=$(date +%s.%N)
    DIFF=$(round 1 "$(echo "$END - $START" | bc)")
    changes=${changes:2}
    additions=$(echo "$changes" | sed 's/ .*$/ /g')
    part=$(round 1 "$(echo "scale=3; 100 * $additions / $lines" | bc)")
    echo "# $date ($changes = $part%, took $DIFF seconds)"
    date=$(date -I -d "$date + 1 day")
done

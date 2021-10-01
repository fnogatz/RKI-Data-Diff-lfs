#!/bin/bash

export LC_NUMERIC="en_US.UTF-8"

TODAY=$(date '+%Y-%m-%d')
SOURCE_DEFAULT="https://github.com/micb25/RKI_COVID19_DATA/raw/master"

URL_METADATA="https://www.arcgis.com/sharing/rest/content/items/f10774f1c63e40168479a1feb6c7ca74?f=json"
URL_DATASET="https://www.arcgis.com/sharing/rest/content/items/f10774f1c63e40168479a1feb6c7ca74/data"

function usage() {
  echo "Usage: ./replay.sh [OPTIONS] [MYSQL_DEFAULTS_FILE]"
  echo
  echo "  Create the SQL query to dump data in the same form as a cleaned CSV."
  echo
  echo "Options:"
  echo
  echo -e "  --start=DATE\t\t\tUse given date as start\n\t\t\t\t(default: $TODAY; first possible is 2020-03-21)"
  echo -e "  --end=DATE\t\t\tUse given date as end\n\t\t\t\t(default: today, i.e. $TODAY)"
  echo -e "  -d=DIR, --dir=DIR\t\tUse this directory for temporary files\n\t\t\t\t(default: /tmp/...)"
  echo -e "  -t=TABLE, --table=TABLE\tUse this SQL table name\n\t\t\t\t(default: rki_csv)"
  echo -e "  --init\t\t\tStart with init phase instead of just updating data"
  echo -e "  --chmod\t\t\tCall chmod for created 2-tmp.csv"
  echo -e "  --stats-only\t\t\tOnly print the LOC of each day's CSV"
  echo -e "  --source=URL\t\t\tGitHub URL of data repository\n\t\t\t\t(default: $SOURCE_DEFAULT)"
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
    -d=* | --dir=*)
      TMP_DIR_USER="${key#*=}"
      shift
      ;;
    -t=* | --table=*)
      TABLE_NAME="${key#*=}"
      shift
      ;;
    --init)
      INIT=true
      shift
      ;;
    --stats-only)
      STATS_ONLY=true
      shift
      ;;
    --chmod)
      CHMOD=true
      shift
      ;;
    --source=*)
      SOURCE_URL="${key#*=}"
      shift
      ;;
    -h | --help)
      usage
      shift
      ;;
    *)
      break
      ;;
  esac
done

if [[ $# -lt 1 && -z "$STATS_ONLY" ]]; then
  usage
fi

MYSQL_DEFAULTS_FILE="$1"
DATE_FROM=${DATE_A:-$TODAY}
DATE_TO=${DATE_B:-$TODAY}
TABLE=${TABLE_NAME:-'rki_csv'}
SOURCE=${SOURCE_URL:-$SOURCE_DEFAULT}

if [[ -z $TMP_DIR_USER ]]; then
  TMP_DIR=$(mktemp -d -p /tmp)
else
  TMP_DIR="$TMP_DIR_USER"
fi

function round() {
  n=$(printf "%.${1}g" "$2")
  if [ "$n" != "${n#*e}" ]; then
    f="${n##*e-}"
    test "$n" = "$f" && f= || f=$((${f#0} + $1 - 1))
    printf "%0.${f}f" "$n"
  else
    printf "%s" "$n"
  fi
}

date="$DATE_FROM"

if [[ ! -z "$INIT" ]]; then
  DATABASE=$(sed -n 's/^database=\([^ ]\+\).*/\1/p' "$MYSQL_DEFAULTS_FILE")
  DUMP_PATH="$TMP_DIR/$TABLE.sql.gz"
  echo "# Create mysqldump in $DUMP_PATH and empty table"
  mysqldump --defaults-extra-file="$MYSQL_DEFAULTS_FILE" "$DATABASE" "$TABLE" | gzip > "$DUMP_PATH"
  echo "DELETE FROM $TABLE;" | mysql --defaults-extra-file="$MYSQL_DEFAULTS_FILE"

  START=$(date +%s.%N)
  echo "# START for $date: table initialisation"
  wget -q "$SOURCE/RKI_COVID19_$date.csv.gz" -O "$TMP_DIR/RKI_COVID19.csv.gz"
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

  if [[ "$date" == "$DATE_TO" ]]; then
    # load from official source
    modified=$(curl -s -X GET -H "Accept: application/json" "$URL_METADATA" 2>&1 | sed -E 's/.*"modified":([0-9]+)000.*/\1/')
    modified=$(date -d "@$modified" '+%Y-%m-%d')
    if [[ "$date" != "$modified" ]]; then
      echo "Updated data for $date does not yet exist (modified date: $modified)"
      exit 1
    fi
    wget -q "$URL_DATASET" -O "$TMP_DIR/RKI_COVID19.csv"
  else
    wget -q "$SOURCE/RKI_COVID19_$date.csv.gz" -O "$TMP_DIR/RKI_COVID19.csv.gz"
    gzip -d -f "$TMP_DIR/RKI_COVID19.csv.gz"
  fi

  lines=$(wc -l "$TMP_DIR/RKI_COVID19.csv" | sed 's/ .*$/ /g')

  if [[ ! -z "$STATS_ONLY" ]]; then
    echo "$date,$lines"
    date=$(date -I -d "$date + 1 day")
    continue
  fi

  ./csv-transform.sh --date="$date" "$TMP_DIR/RKI_COVID19.csv" | ./csv-sort.sh > "$TMP_DIR/1-init.csv"
  rm -f "$TMP_DIR/2-tmp.csv"
  ./create-sql-query.sh --known-before --date="$date" "$TMP_DIR/2-tmp.csv" | mysql --defaults-extra-file="$MYSQL_DEFAULTS_FILE"
  
  if [[ ! -z "$CHMOD" ]]; then
    sudo chmod o+r "$TMP_DIR/2-tmp.csv"
  fi

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

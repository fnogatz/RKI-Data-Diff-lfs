#!/bin/bash

TODAY=$(date '+%Y-%m-%d')

function usage() {
  echo "Usage: ./create-sql-query.sh [OPTIONS] FILENAME"
  echo
  echo "  Create the SQL query to dump data in the same form as a cleaned CSV."
  echo
  echo "Options:"
  echo
  echo -e "  -d=DATE, --date=DATE\t\tUse given date (default: $TODAY)"
  echo -e "  --known-before\t\tReturn only rows that are known before the given date"
  echo -e "  -t=TABLE, --table=TABLE\tUse this SQL table name (default: rki_csv)"
  echo -e "  -h, --help\t\t\tShow this message and exit"
  exit
}

while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    -d=* | --date=*)
      DATE="${key#*=}"
      shift
      ;;
    --known-before)
      KNOWN_BEFORE=true
      shift
      ;;
    -t=* | --table=*)
      TABLE_NAME="${key#*=}"
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

if [[ $# -lt 1 ]]; then
  usage
fi

FILENAME=$1
REF_DATE=${DATE:-$TODAY}
TABLE=${TABLE_NAME:-'rki_csv'}

REF_DATE_COMPARISON="$REF_DATE"
if [[ $KNOWN_BEFORE ]]; then
  REF_DATE_COMPARISON=$(date -d @$(($(date -d $REF_DATE +"%s") - 24 * 3600)) +"%Y-%m-%d")
fi

cat << ENDMYSQL
SELECT
    'IdBundesland',
    'IdLandkreis',
    'Meldedatum',
    'Altersgruppe',
    'Geschlecht',
    'NeuerFall',
    'NeuerTodesfall',
    'NeuGenesen',
    'AnzahlFall',
    'AnzahlTodesfall',
    'AnzahlGenesen',
    'Refdatum',
    'IstErkrankungsbeginn',
    'Altersgruppe2',
    'GueltigAb',
    'GueltigBis',
    'DFID'
UNION ALL
SELECT
    IdBundesland,
    IdLandkreis,
    Meldedatum,
    Altersgruppe,
    Geschlecht,
    IF(NeuerFall = 1 AND GueltigAb < "$REF_DATE", 0, NeuerFall),
    IF(NeuerTodesfall = 1 AND GueltigAb < "$REF_DATE", 0, NeuerTodesfall),
    IF(NeuGenesen = 1 AND GueltigAb < "$REF_DATE", 0, NeuGenesen),
    AnzahlFall,
    AnzahlTodesfall,
    AnzahlGenesen,
    Refdatum,
    IstErkrankungsbeginn,
    Altersgruppe2,
    "$REF_DATE",
    NULL,
    DFID
FROM $TABLE
WHERE
    GueltigAb <= "$REF_DATE_COMPARISON" AND
    (GueltigBis IS NULL OR "$REF_DATE_COMPARISON" <= GueltigBis)
INTO OUTFILE '$FILENAME'
CHARACTER SET UTF8 FIELDS TERMINATED BY ','
LINES TERMINATED BY '\n';
ENDMYSQL

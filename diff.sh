#!/bin/bash

TODAY=$(date '+%Y-%m-%d')

usage() {
  echo "Usage: patch [OPTIONS] STATE CSV"
  echo
  echo "  Generate SQL-commands from two CSV dumps."
  echo
  echo "Options:"
  echo
  echo -e "  -h, --help\t\t\tShow this message and exit"
  exit
}

print_changes() {
  if [[ n_additions -gt 0 || n_deletions -gt 0 ]]; then
    # print previous change

    if [[ n_deletions -eq 0 ]]; then
      # additions only

      to="$((row2line + 1))"
      if [[ n_additions -gt 1 ]]; then
        to+=",$((row2line + n_additions))"
      fi
      echo "${row1line}a$to"
      printf '> %s\n' "${additions[@]}"
      ((row2line += n_additions))

    elif [[ n_additions -eq 0 ]]; then
      # removals only; must be encoded as changes

      from="$((row1line))"
      if [[ n_deletions -gt 1 ]]; then
        from="$((row1line - n_deletions + 1)),$from"
      fi
      to="$((row2line + 1))"
      if [[ n_deletions -gt 1 ]]; then
        to+=",$((row2line + n_deletions))"
      fi
      echo "${from}c${to}"
      printf '< %s\n' "${deletions[@]}"
      echo "---"
      printf '> %s\n' "${deletions[@]}" | sed -E "s/,\\\\N,([0-9]{15})/,$REF_YESTERDAY,\\1/"
      ((row2line += n_deletions))

    else
      # real changes

      from="$((row1line))"
      if [[ n_deletions -gt 1 ]]; then
        from="$((row1line - n_deletions + 1)),$from"
      fi
      to="$((row2line + 1)),$((row2line + n_deletions + n_additions))"
      echo "${from}c${to}"
      printf '< %s\n' "${deletions[@]}"
      echo "---"
      (
        printf '> %s\n' "${deletions[@]}" | sed -E "s/,\\\\N,([0-9]{15})/,$REF_YESTERDAY,\\1/" \
          && printf '> %s\n' "${additions[@]}"
      ) | sort
      ((row2line += n_additions + n_deletions))
    fi

    changed=1
    # reset change
    additions=()
    n_additions=0
    deletions=()
    n_deletions=0
  fi
}

process_row1() {
  i=1
  IFS=',' read -ra ROW <<< "$row1"
  if [[ "${ROW[14]}" < "$REF_TODAY" ]]; then
    row1=""
    for col in "${ROW[@]}"; do
      if [[ "$col" == "1" && ($i -eq 6 || $i -eq 7 || $i -eq 8 ) ]]; then
        row1+="0,"
      else
        row1+="$col,"
      fi
      ((i++))
    done
    row1=${row1::-1}
  fi

  data1=${row1::-30}
  metadata1=${row1: -29}

  gueltig_bis=${metadata1::-16}
  gueltig_bis=${gueltig_bis: -10}

  if [[ $gueltig_bis =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2} && ! "$gueltig_bis" > "$REF_YESTERDAY" ]]; then
    # skip row1 as its already set to be not valid anymore
    if read -r row1 <&3; then
      process_row1
    else
      data1=""
    fi
    ((row1line++))
  fi
}

while [[ $# -gt 2 ]]; do
  key="$1"
  case $key in
    -h | --help)
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

exec 3< "$1"
exec 4< "$2"

read -r row1 <&3 && read -r row2 <&4 # omit very first line

# read in and preprocess second line
read -r row1 <&3
read -r row2 <&4
process_row1
data2=${row2::-30}
metadata2=${row2: -29}

# store today's date from file2
dfid=${row2: -15}
yyyymmdd="${dfid:0:4}-${dfid:4:2}-${dfid:6:2}"
REF_TODAY=$(date -d @$(date -d $yyyymmdd +"%s") +"%Y-%m-%d")
REF_YESTERDAY=$(date -I -d "$yyyymmdd - 1 day")

row1line=1
row2line=1
additions=()
n_additions=0
deletions=()
n_deletions=0
changed=0

diff_additions=0
diff_deletions=0

# loop through all lines
while [[ -n "$data1" || -n "$data2" ]]; do
  # switch columns `NeuerFall`, `NeuerTodesfall`, `NeuGenesen`

  if [[ "$data1" == "$data2" ]]; then
    print_changes

    if read -r row1 <&3; then
      process_row1
    else
      data1=""
    fi
    ((row1line++))

    if read -r row2 <&4; then
      data2=${row2::-30}
      metadata2=${row2: -29}
    else
      data2=""
    fi
    ((row2line++))

  elif [[ "$data1" > "$data2" ]]; then
    # new line detected

    if [[ -n "$data2" ]]; then
      # addition of data2
      additions+=("$row2")
      ((n_additions++))
      ((diff_additions++))

      if read -r row2 <&4; then
        data2=${row2::-30}
        metadata2=${row2: -29}
      else
        data2=""
      fi
    else
      # removal of data1, since file2 ended before
      deletions+=("$row1")
      ((n_deletions++))
      ((diff_deletions++))

      # continue with the rest of file1
      if read -r row1 <&3; then
        process_row1
      else
        data1=""
      fi
      ((row1line++))
    fi

  elif [[ "$data2" > "$data1" ]]; then
    # deleted line detected

    if [[ -n "$data1" ]]; then
      # removal of data1
      deletions+=("$row1")
      ((n_deletions++))
      ((diff_deletions++))

      if read -r row1 <&3; then
        process_row1
      else
        data1=""
      fi
      ((row1line++))
    else
      # addition of data2, since file1 ended before
      additions+=("$row2")
      ((n_additions++))
      ((diff_additions++))

      # continue with the rest of file2
      if read -r row2 <&4; then
        data2=${row2::-30}
        metadata2=${row2: -29}
      else
        data2=""
      fi
    fi
  fi
done

# check for remaining removals and additions

print_changes
echo "@@ $diff_additions insertions(+), $diff_deletions deletions(-)"
exit "$changed"

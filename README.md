# RKI Data Diff

**WIP – Work in Progress!**

Shell scripts to get a minimal set of SQL commands for persistent yet efficient storage of RKI data for COVID19.

This repository contains scripts to compare two dumps of RKI data given as unsorted CSV files and create a minimal set of SQL commands to go from one to the other. It consists of three parts:

- `transform-csv.sh`, which transforms a CSV into a cleaned and sorted form that can be imported as initial state into SQL.
- `diff.sh`, which generates a minimal patch file for two CSV files.
- `patch.sh`, which takes a patch file for CSV rows and generates appropriate SQL commands to get from one data version to the other.

Each Bash script comes with its own command line arguments, so simply call it with `--help` to get a full list of options.

## Usage

The overall process to keep track of all data changes consists of two phases: the *initialisation* creates the SQL table and imports the initial state from a single CSV file; the *update* phase then calculates a set of minimal SQL commands to keep track of all changes and should be run once a day.

### Initialisation

First, create the SQL table `rki_csv`:

```sh
cat sql/create-table.sql | mysql # -u scll -p scll
```

The initial data can be created from a given RKI CSV file as follows:

```sh
./init.sh --date=2021-04-23 data/RKI_COVID19_2021-04-23.csv > data/RKI_COVID19_2021-04-23_init.csv
```

Load this CSV into SQL:

```sql
LOAD DATA LOCAL INFILE '/home/fnogatz/DFKI/Development/RKI-Diff-Data/data/RKI_COVID19_2021-04-22_init.csv' INTO TABLE rki_csv CHARACTER SET UTF8 FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' IGNORE 0 LINES;
```

### Update SQL Data

Create the patch file and corresponding SQL statements:

```sh
./diff.sh data/RKI_COVID19_2021-04-22.csv data/RKI_COVID19_2021-04-23.csv > data/22-23.diff
cat data/22-23.diff | ./patch.sh --date=2021-04-23 > data/22-23.sql
```

### Check

```sql
SELECT IdBundesland, IdLandkreis, Meldedatum, Altersgruppe, Geschlecht, NeuerFall, NeuerTodesfall, NeuGenesen, AnzahlFall, AnzahlTodesfall, AnzahlGenesen, Refdatum, IstErkrankungsbeginn, Altersgruppe2, "2021-04-22", NULL
FROM
    rki_csv
WHERE 1=1
INTO OUTFILE '/var/lib/mysql-files/RKI_COVID19_2021-04-22_check.csv'
CHARACTER SET UTF8 FIELDS TERMINATED BY ','
LINES TERMINATED BY '\n';
```

## Definition of CSVs

Columns provided by RKI:

1.  FID
2.  IdBundesland
3.  Bundesland
4.  Landkreis
5.  Altersgruppe
6.  Geschlecht
7.  AnzahlFall
8.  AnzahlTodesfall
9.  Meldedatum
10. IdLandkreis
11. Datenstand
12. NeuerFall
13. NeuerTodesfall
14. Refdatum
15. NeuGenesen
16. AnzahlGenesen
17. IstErkrankungsbeginn
18. Altersgruppe2

Columns after applying `transform-csv.sh`:

1.  IdBundesland
2.  IdLandkreis
3.  Meldedatum
4.  Altersgruppe
5.  Geschlecht
6.  NeuerFall
7.  NeuerTodesfall
8.  NeuGenesen
9.  AnzahlFall
10. AnzahlTodesfall
11. AnzahlGenesen
12. Refdatum
13. IstErkrankungsbeginn
14. Altersgruppe2

Spalten *Neu\**

- `0`: Fall (Anzahl > 0) ist heute drin, war gestern auch schon drin
- `1`: Fall (Anzahl > 0) ist heute neu drin, war gestern noch nicht drin (= Korrektur nach oben)
- `-1`: Fall (Anzahl >= 0) ist heute nicht mehr drin, war gestern aber noch drin (= Korrektur nach unten)
- `-9`: Anzahl ist bislang immer NULL gewesen (wie `0`, aber Anzahl >= 0)

## Background

The RKI publishes every day a new CSV dump of all COVID19 cases in Germany, where only about 2% of all data rows are changed per day. However, only the aggregeated CSV dumps are known for synchronisation. In order to get a minimal set of instructions to go from one data version to the other, this repository was created. It adopts ideas and code from the more generic [`tablediff` tool](https://github.com/fnogatz/tablediff), which serves a similar purpose for any CSV.

The Bash scripts use a combination of shell's `awk`, `sort`, `cmp`, and diff commands, to split, sort, and compare large CSV files in a best-effort manner.

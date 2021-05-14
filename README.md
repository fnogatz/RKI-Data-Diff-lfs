# RKI Data Diff

Shell scripts to get a minimal set of SQL commands for persistent yet efficient storage of RKI data for COVID19.

This repository contains scripts to process RKI data given as unsorted CSV files and create a minimal set of SQL commands to go preserve its full history of updates. It consists of four parts:

- `csv-transform.sh`, which transforms a CSV provided by RKI into a cleaned form that can be imported as the initial state into SQL.
- `csv-sort.sh`, which sorts this CSV file.
- `create-sql-query.sh`, which creates the SQL query to dump data in the same form as a cleaned CSV.
- `patch.sh`, which takes two CSV files and generates SQL commands to get from the current state stored in the SQL table to the new state provided by the RKI dump.

In addition, `replay.sh` allows to automate this process for a given time span.

Each Bash script comes with its own command line arguments, so simply call them with `--help` to get a full list of options.

## Usage

The overall process to keep track of all data changes consists of three phases: the *initialisation* creates the SQL table and imports the initial state from a single CSV file provided by RKI. In the second *update* phase, a set of updates is calculated to keep track of all changes and should be run once a day. To test the correctness of some state, the same scripts can be applied in an optional *check* phase.

### Initialisation

First, create the SQL table `rki_csv`:

```sh
cat create-table.sql | mysql # -u [username] -p [database]
```

The initial data can be created from a given RKI CSV file as follows:

```sh
cat data/RKI_COVID19_2021-04-22.csv | ./csv-transform.sh --date=2021-04-22 | ./csv-sort.sh > data/RKI_COVID19_2021-04-22_init.csv
```

Load this CSV into SQL:

```sql
LOAD DATA LOCAL INFILE '/path/to/data/RKI_COVID19_2021-04-22_init.csv' INTO TABLE rki_csv CHARACTER SET UTF8 FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' IGNORE 1 LINES;
```

### Update SQL Data

Create the cleaned and sorted CSV from a given RKI CSV file. This is the same procedure as for the initialisation:

```sh
cat data/RKI_COVID19_2021-04-23.csv | ./csv-transform.sh --date=2021-04-23 | ./csv-sort.sh > data/RKI_COVID19_2021-04-23_init.csv
```

Create an unsorted CSV dump of the state currently stored in the SQL table:

```sh
./create-sql-query.sh --known-before --date=2021-04-23 /path/to/data/RKI_COVID19_2021-04-23_tmp.csv | mysql # -u [username] -p [database]
```

Sort the generated file:

```sh
cat data/RKI_COVID19_2021-04-23_tmp.csv | ./csv-sort.sh > data/RKI_COVID19_2021-04-23_predump.csv
```

Compare it to the latest RKI CSV, generate a minimal set of changes, and load them into SQL:

```sh
./patch.sh data/RKI_COVID19_2021-04-23_predump.csv data/RKI_COVID19_2021-04-23_init.csv | mysql # -u [username] -p [database]
```

### Check

To get the data as if it were some given date, just call the query created by `./create-sql-query.sh`:

```sh
./create-sql-query.sh --date=2021-04-23 /path/to/data/RKI_COVID19_2021-04-23_dump.csv | mysql # -u [username] -p [database]
```

The generated file can be checked against the official RKI CSV dump for this date as follows:

```sh
diff <(cat data/RKI_COVID19_2021-04-23_dump.csv | ./csv-sort.sh --without-metadata) <(cat data/RKI_COVID19_2021-04-23_init.csv | ./csv-sort.sh --without-metadata)
```

## Background

The RKI publishes every day a new CSV dump of all COVID19 cases in Germany, where only about 2% of all data rows are changed per day. However, only the aggregeated CSV dumps are known for synchronisation. In order to get a minimal set of instructions to go from one data version to the other, this repository was created. It adopts ideas and code from the more generic [`tablediff` tool](https://github.com/fnogatz/tablediff), which serves a similar purpose for any pair of two CSV dumps.

The Bash scripts use a combination of shell's `awk`, `sort`, and `diff` commands, to split, sort, and compare large CSV files and SQL dumps in a best-effort manner.

## FAQ

#### Why don't you use only the latest CSV dump?

With a single CSV dump provided by the RKI, you lose all information about previous corrections in the data. If you ever wondered *What were the numbers known at this specific date the past?*, i.e. the exact numbers that the [RKI Dashboard](http://corona.rki.de/) listed, this repository is for you. In particular if you hesitate to store the original CSV files for each day, and instead wish to run ad-hoc queries about *all* these data with SQL.

#### How does `rki-data-diff` work?

The idea is to identify rows that have changed in the RKI CSV dumps of two consecutive days. As of April 2021, this saves around 98% of space. Per day, there are only between 25k and 35k rows that are added, instead of the original 1.7 million rows in the RKI CSV dumps.

#### Why don't you refer to the CSV's column `FID` to identify changed rows?

The `FID` is consistent and unique only within the CSV dump of a single day. Even if the values of data row do not change, it is not guaranteed to have the same `FID` in the CSV dump provided by the RKI the next day.

#### How is the primary key `DFID` built?

The field `DFID` is an integer of 15 digits, where the first 8 are the date when this row first appear in the format `YYYYMMDD`, the rest are the corresponding row number, filled up by leading zeroes. I.e., a `DFID` of `202104220001813` describes the row 1813 from the RKI CSV file of 2021/04/22.

#### Why is the primary key `DFID` the last column?

It makes it easier to sort the CSV dumps by their values via the shell's `sort` command.

#### What's the performance of this approach?

Some numbers on an i5, 4x 2.30GHz:

- The *initialisation* phase takes about 75 seconds: ~60sec for `.csv-transform.csv` and `csv-sort.sh`, plus ~15sec for loading the data in SQL.
- The *update* phase takes about 5 minutes: ~1min for `.csv-transform.csv` and `csv-sort.sh`, plus ~3min for `./patch.sh` and SQL updates, and less than a minute for the intermediate steps.
- The optional *check* phase takes about 2 minutes, with most of this time spent to calculate the (empty) `diff`.

#### What's the form of the original RKI CSV files?

We constantly refer to the column numbers in our scripts, so the following list might come in useful:

1.  `FID`
2.  `IdBundesland`
3.  `Bundesland`
4.  `Landkreis`
5.  `Altersgruppe`
6.  `Geschlecht`
7.  `AnzahlFall`
8.  `AnzahlTodesfall`
9.  `Meldedatum`
10. `IdLandkreis`
11. `Datenstand`
12. `NeuerFall`
13. `NeuerTodesfall`
14. `Refdatum`
15. `NeuGenesen`
16. `AnzahlGenesen`
17. `IstErkrankungsbeginn`
18. `Altersgruppe2`

#### What's the form of the cleaned CSVs?

After applying `csv-transform.sh`, the CSV files are of the following columns:

1.  `IdBundesland`
2.  `IdLandkreis`
3.  `Meldedatum` (format `YYYY-MM-DD`)
4.  `Altersgruppe`
5.  `Geschlecht`
6.  `NeuerFall`
7.  `NeuerTodesfall`
8.  `NeuGenesen`
9.  `AnzahlFall`
10. `AnzahlTodesfall`
11. `AnzahlGenesen`
12. `Refdatum` (format `YYYY-MM-DD`)
13. `IstErkrankungsbeginn`
14. `Altersgruppe2`
15. `GueltigAb`
16. `GueltigBis`
17. `DFID`

Note that the flag `--without-metadata` provided by the scripts `csv-transform.sh` and `csv-sort.sh` removes the last three columns `GueltigAb`, `GueltigBis`, and `DFID`. This makes it easier to compare two CSV files, as for instance done in the optional *check* phase.

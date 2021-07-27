# Example Queries

In the following, we give example queries for the region _SK Kaiserslautern_, which is identified by `IdLandkreis = '07312'`. To get the data for Germany, just remove this conditional expression in all queries.

Note that every query has to consider two dates:

- `REF_DATE`: This is the _reference date_ for queries, to answer questions like: How many people were infected on/until that day?
- `VERSION_DATE`: This sets the date for the data version. Since many entries are corrected or collected only after some time, the previously mentioned question might result in different answers for the same `REF_DATE` but different `VERSION_DATE`.

Note that it is always `REF_DATE <= VERSION_DATE`. If you want to collect the information in the same form they were available at a given date (i.e., how they were reported in the RKI dashboard), you have to choose `REF_DATE = VERSION_DATE`.

On each query you have to specify the `VERSION_DATE` in the WHERE-clause as follows:

```sql
... WHERE (GueltigBis IS NULL OR GueltigBis >= 'VERSION_DATE') AND GueltigAb <= 'VERSION_DATE'
```

In contrast, the specification of `REF_DATE` depends on your actual query.

## Sum of Cases

### _How many cases were reported in total for SK Kaiserslautern on 2021-07-23?_

This returns the value that was displayed at RKI Dashboard on 2021-07-23.

```sql
SELECT SUM(AnzahlFall) FROM rki_csv
WHERE
  IdLandkreis = '07312' AND
  AnzahlFall > 0 AND
  (GueltigBis IS NULL OR GueltigBis >= '2021-07-23') AND GueltigAb <= '2021-07-23'; # VERSION_DATE
# SUM(AnzahlFall) = 3773 [2 sec]
```

### _How many cases happened actually for SK Kaiserslautern until 2021-07-23, given all data from 2021-07-27?_

This returns the actual value for 2021-07-23 (`REF_DATE`) given all data corrections known on 2021-07-27 (`VERSION_DATE`).

```sql
SELECT SUM(AnzahlFall) FROM rki_csv
WHERE
  IdLandkreis = '07312' AND
  AnzahlFall > 0 AND
  Meldedatum < '2021-07-23' AND # REF_DATE
  (GueltigBis IS NULL OR GueltigBis >= '2021-07-27') AND GueltigAb <= '2021-07-27'; # VERSION_DATE
# SUM(AnzahlFall) = 3767 [2 sec]
```

## Sum of Deaths

The queries are the same as for the _Sum of Cases_, just replace all occurrences of `AnzahlFall` by `AnzahlTodesfall`.

## New Cases

```sql
SELECT SUM(AnzahlFall) FROM rki_csv
WHERE
  IdLandkreis = '07312' AND
  NeuerFall != 0 AND
  (GueltigBis IS NULL OR GueltigBis >= '2021-07-27') AND GueltigAb = '2021-07-27'; # VERSION_DATE
# SUM(AnzahlFall) = 7 [2 sec]
```

## New Deaths

```sql
SELECT SUM(AnzahlTodesfall) FROM rki_csv
WHERE
  IdLandkreis = '07312' AND
  NeuerTodesfall != 0 AND
  (GueltigBis IS NULL OR GueltigBis >= '2021-07-27') AND GueltigAb = '2021-07-27'; # VERSION_DATE
# SUM(AnzahlTodesfall) = 0 [2 sec]
```

## Cases per 7 Days

### _How many cases per last 7 days were reported for SK Kaiserslautern on 2021-07-23, i.e. for the timespan July 16-22 2021?_

```sql
SELECT SUM(AnzahlFall) FROM rki_csv
WHERE
  IdLandkreis = '07312' AND
  Meldedatum BETWEEN '2021-07-16' AND '2021-07-22' AND # REF_DATE = 2021-07-23
  AnzahlFall > 0 AND
  (GueltigBis IS NULL OR GueltigBis >= '2021-07-23') AND GueltigAb <= '2021-07-23'; # VERSION_DATE
# SUM(AnzahlFall) = 57 [2 sec]
```

### _How many cases per last 7 days actually happened for SK Kaiserslautern in the timespan July 16-22 2021?_

This returns the actual value for the timespan 2021-07-16 to 2021-07-22 (i.e., `REF_DATE = 2021-07-23`), given all data corrections and additions known on 2021-07-27 (`VERSION_DATE`).

```sql
SELECT SUM(AnzahlFall) FROM rki_csv
WHERE
  IdLandkreis = '07312' AND
  Meldedatum BETWEEN '2021-07-16' AND '2021-07-22' AND # REF_DATE = 2021-07-23
  AnzahlFall > 0 AND
  (GueltigBis IS NULL OR GueltigBis >= '2021-07-27') AND GueltigAb <= '2021-07-27'; # VERSION_DATE
# SUM(AnzahlFall) = 51 [2 sec]
```

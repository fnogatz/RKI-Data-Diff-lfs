# Example Queries

In the following, we give example queries for the region _SK Kaiserslautern_, which is identified by `IdLandkreis = '07312'`. To get the data for Germany, just remove this conditional expression in all queries.

Note that every query has to consider two dates:

- `REF_DATE`: This is the _reference date_ for queries, to answer questions like: How many people were infected on/until that day?
- `VERSION_DATE`: This sets the date for the data version. Since many entries are corrected or collected only after some time, the previously mentioned question might result in different answers for the same `REF_DATE`, just depending on the data version.

Note that `REF_DATE <= VERSION_DATE`. If you want to collect the information in the same form they were available at a given date, you have to choose `REF_DATE = VERSION_DATE`.

On earch query you have to specify the `VERSION_DATE` in the WHERE-clause as follows:

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
  (GueltigBis IS NULL OR GueltigBis >= '2021-07-23') AND GueltigAb <= '2021-07-23';
```

### _How many cases happened actually for SK Kaiserslautern until 2021-07-23, given all data from 2021-07-27?_

This returns the actual value for 2021-07-23 (`REF_DATE`) given all data corrections known on 2021-07-27 (`VERSION_DATE`).

```sql
SELECT SUM(AnzahlFall) FROM rki_csv
WHERE
  IdLandkreis = '07312' AND
  AnzahlFall > 0 AND
  Meldedatum < '2021-07-23' AND
  (GueltigBis IS NULL OR GueltigBis >= '2021-07-27') AND
  GueltigAb <= '2021-07-27';
```

## Sum of Deaths

The queries are the same as for the _Sum of Cases_, just replace all occurrences of `AnzahlFall` by `AnzahlTodesfall`.

## New Cases

```sql
SELECT SUM(AnzahlFall) FROM rki_csv
WHERE
  IdLandkreis = '07312' AND
  NeuerFall != 0 AND
  (GueltigBis IS NULL OR GueltigBis >= '2021-07-27') AND GueltigAb = '2021-07-27';
```

## New Deaths

```sql
SELECT SUM(AnzahlTodesfall) FROM rki_csv
WHERE
  IdLandkreis = '07312' AND
  NeuerTodesfall != 0 AND
  (GueltigBis IS NULL OR GueltigBis >= '2021-07-27') AND GueltigAb = '2021-07-27';
```

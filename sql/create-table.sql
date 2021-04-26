CREATE TABLE IF NOT EXISTS rki_csv(
  IdBundesland         INTEGER NOT NULL,
  IdLandkreis          VARCHAR(5) NOT NULL,
  Meldedatum           DATE NOT NULL,
  Altersgruppe         VARCHAR(9) NOT NULL,
  Geschlecht           VARCHAR(9) NOT NULL,
  NeuerFall            INTEGER NOT NULL,
  NeuerTodesfall       INTEGER NOT NULL,
  NeuGenesen           INTEGER NOT NULL,
  AnzahlFall           INTEGER NOT NULL,
  AnzahlTodesfall      INTEGER NOT NULL,
  AnzahlGenesen        INTEGER NOT NULL,
  Refdatum             DATE NOT NULL,
  IstErkrankungsbeginn INTEGER NOT NULL,
  Altersgruppe2        VARCHAR(20) NOT NULL,
  GueltigAb            DATE NOT NULL,
  GueltigBis           DATE NULL
) DEFAULT CHARACTER SET = UTF8;

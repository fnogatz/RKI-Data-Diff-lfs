{
    if (NR==1) {
        split(columns,cols,",");
        for(i=1; i<=NF; i++) {
            cell[$i]=i;
        }
        if (without_metadata!="true") {
            columns=columns",GueltigAb,GueltigBis,DFID";
        }
        print columns;
    } else {
        if (cell["Meldedatum"] > 0) {
            if ($cell["Meldedatum"] ~ /^[0-9]{13}$/) {
                # UNIX timestamp in milliseconds
                $cell["Meldedatum"]=strftime("%Y-%m-%d",substr($cell["Meldedatum"],1,10));
            } else {
                sub(/ .*/, "", $cell["Meldedatum"]);
                gsub(/\//, "-", $cell["Meldedatum"]);
                $cell["Meldedatum"]=substr($cell["Meldedatum"],1,10);
            }
        }
        if (cell["Refdatum"] > 0) {
            if ($cell["Refdatum"] ~ /^[0-9]{13}$/) {
                # UNIX timestamp in milliseconds
                $cell["Refdatum"]=strftime("%Y-%m-%d",substr($cell["Refdatum"],1,10));
            } else {
                sub(/ .*/, "", $cell["Refdatum"]);
                gsub(/\//, "-", $cell["Refdatum"]);
                $cell["Refdatum"]=substr($cell["Refdatum"],1,10);
            }
        }
        row="";
        comma="";

        for(i in cols) {
            column=cols[i];
            ref=cell[column];
            if (ref > 0) {
                row=row comma $ref;
            } else {
                row=row comma "\\N";
            }
            comma=",";
        }

        if (without_metadata!="true") {
            gsub(/\//, "-", gueltigab);
            dfid=sprintf("%s%07d", gueltigab, NR-1);
            gsub(/-/, "", dfid);
            row=row","gueltigab",\\N,"dfid;
        }
        print row;
    }
}

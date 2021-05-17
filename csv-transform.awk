function parse_date(input) {
    if (input ~ /^[0-9]{13}$/) {
        # UNIX timestamp in milliseconds
        return strftime("%Y-%m-%d",substr(input,1,10));
    } else if (input ~ /^(1[012]|[1-9])\/[0-9]{1,2}\/20[0-9]{2}$/) {
        # mm/dd/yyyy
        split(input,parts,"/");
        yyyy=parts[3];
        mm=parts[1];
        if (length(mm) == 1) {
            mm="0" mm;
        }
        dd=parts[2];
        if (length(dd) == 1) {
            dd="0" dd;
        }
        return yyyy "-" mm "-" dd;
    } else if (input ~ /^([1-9]|[12][0-9]|3[01])\.(1[012]|[1-9])\.20[0-9]{2}/) {
        # dd.mm.yyyy
        sub(/ .*/, "", input);
        split(input,parts,".");
        yyyy=parts[3];
        mm=parts[2];
        if (length(mm) == 1) {
            mm="0" mm;
        }
        dd=parts[1];
        if (length(dd) == 1) {
            dd="0" dd;
        }
        return yyyy "-" mm "-" dd;
    } else {
        sub(/ .*/, "", input);
        gsub(/\//, "-", input);
        return substr(input,1,10);
    }
}
function normalise_name(name) {
    gsub(/"/, "", name);
    if (name == "Landkreis ID") {
        return "IdLandkreis";
    }
    if (name == "Referenzdatum" || name == "Refdatum2") {
        return "Refdatum";
    }
    if (name == "Meldedatum2") {
        return "Meldedatum";
    }
    gsub(/ /, "", name);
    return name;
}
function normalise_value(name, value) {
    gsub(/"/, "", value);
    if (value ~ /\.00$/) {
        value=substr(value,1,length(value)-3);
    }
    if (name == "IdLandkreis") {
        if (length(value) == 4) {
            return "0" value;
        }
    }
    if (name == "Altersgruppe2") {
        if (value == "" || value == "Nicht übermittelt") {
            return "\\N";
        }
    }
    return value;
}

{
    if (NR==1) {
        split(columns,cols,",");
        for(i=1; i<=NF; i++) {
            name=normalise_name($i);
            cell[name]=i;
        }
        if (without_metadata!="true") {
            columns=columns",GueltigAb,GueltigBis,DFID";
        }
        print columns;
    } else {
        if (cell["Meldedatum"] > 0) {
            $cell["Meldedatum"]=parse_date($cell["Meldedatum"]);
        }
        if (cell["Refdatum"] > 0) {
            $cell["Refdatum"]=parse_date($cell["Refdatum"]);
        }
        row="";
        comma="";

        for(i in cols) {
            column=cols[i];
            ref=cell[column];
            if (ref > 0) {
                row=row comma normalise_value(column, $ref);
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

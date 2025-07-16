BEGIN { FS="\t"; }

(NR==FNR) {
    if (($3==9606)||($3==10090)||($3==1165090)||($3==570278)||\
	($3==332249)||($3==9031)||($3==9823)||($3==9615)) {
	remove[$2]=1;
    }
}

(NR!=FNR) {
    if (FNR % 4 == 1) {
	split($0,line_array," ");
	key=substr(line_array[1],2);
	if (key in remove) {
	    out = 0;
	} else {
	    out = 1;
	    print $0;
	}
    } else {
	if (out) {
	    print $0;
	}
    }
}

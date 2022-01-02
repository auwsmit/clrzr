#!/usr/bin/awk

BEGIN {

	FS = "\n"
	rHex = "[[:xdigit:]]"
	rSpc = "[[:space:]]*"
	rFlt = "([0-9]*\\.)?[0-9]+"
	rPct = rFlt "%"
	rFltOrPct = rFlt "%?"
	cma = rSpc "," rSpc

	rExpr = "(" \
		"(0x|#)(" rHex "{8}|" rHex "{6}|" rHex "{4}|" rHex "{3})" \
		"|" \
		"(rgb|rgba)\\(" rSpc rFltOrPct cma rFltOrPct cma rFltOrPct "(" cma rFltOrPct ")?" rSpc "\\)" \
		"|" \
		"(hsl|hsla)\\(" rSpc rFlt cma rPct cma rPct "(" cma rFltOrPct ")?" rSpc "\\)" \
	")"

	rLineNo = "^" rSpc "[0-9]+\t"
}

{
	if( $1 == "--END--" ) {
		print $1
	}
	else {

		szLine = tolower($1)

		# GET LINE#
		match(szLine, rLineNo)
		if( RLENGTH >= 0 ) {

			szLineNo = substr(szLine, RSTART, RLENGTH - 1)
			szLine = substr(szLine, RSTART + RLENGTH)
			colAbs = 0

			# GET COLORS WITHIN LINE
			while( 1 ) {

				match(szLine, rExpr)
				colAbs += RSTART

				if( RLENGTH < 0 ) {
					break
				}

				printf "%s|%d|%d|%s\n", szLineNo, colAbs, RLENGTH, substr(szLine, RSTART, RLENGTH)
				colAbs += RLENGTH - 1
				szLine = substr(szLine, RSTART + RLENGTH)
			}
		}
	}

	fflush()
}

# GAWK: --sandbox
# AWK: --safe
#
# awk -f ./clrzr.awk ./colortest.txt | sort | uniq

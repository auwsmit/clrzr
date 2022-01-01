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
}

{
	szLine = $1
	while( 1 ) {

		match(szLine, rExpr)

		if( RLENGTH < 0 ) {
			break
		}

		print substr(szLine, RSTART, RLENGTH)
		fflush()
		szLine = substr(szLine, RSTART + RLENGTH)
	}
}

# GAWK: --sandbox
# AWK: --safe
#
# awk -f ./clrzr.awk ./colortest.txt | sort | uniq

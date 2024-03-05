# Flag Extended Cross References
This repo contains scripts to mark the target of Extended cross references.

### Extended Cross Reference
An extended cross reference (xcf) is one where the target has more than just the lx/lc field of the target. Here is an example from Tetun Dili (some fields have been removed from the original). The additional fields within the xcf are separated by a special EOL marker (__LS__ below).

The special EOL marker is included in the .ini file.

````SFM
\lx aman
\hm 2
\sn
\ps adj
\ge male (animal)
\de male (of animals)
\gn jantan (binatang)
\gr macho (m) ; masculino (m)
\dr macho (m) (animal), masculino (m) (ai horis)

\lf CPart
\lv inan__LS__\le female (animal)
\cf busa aman__LS__\ce tomcat
\cf karau aman__LS__\ce bull
\cf kuda aman__LS__\ce stallion
````
## The INI file
The ini file should have sections with syntax like this:
````INI
[FlagXtXref]
recmark=lx
hmmark=hm
semarks=se,sec,sed,sei,sep,sesec,sesed,sesep,seses
xrefmarks=lv,cf
lcmark=lc
REFflag=REF
dtmarks=dt,date
xteol=__LS__
````
## Targets of Cross References
Valid targets of cross references are stored.
For each target, its homographs and their locations are tracked. 
## Checks on Targets of Cross References
The lexical file is processed for valid targets of cross references.
Targets can be duplicated as long as they have different homograph markers.
Error messages are logged to the error file when the following ambiguities are detected:
- Duplicate targets with no homograph markers
- Duplicate targets with identical homograph markers
- Duplicate targets some with homograph markers others without.

## Restrictions on \\hm fields
The homograph field of the main entry must be one of the first four fields. Homograph markers outside that range are considered to be contained in a subentry.

## To Do
- Keep track of the original line numbers of the start of the records (i.e. EOL + previous special EOLs).
- Some of the code assumes that the eol replacement string in the internal opl is a single character. It shouldn't. This may be a problem that can be ignored.
 - If any of the targets or xrefs contain the eol replacement string, It will be replaced in the error and log files. E.g. "this#word" would be logged or flagged as "this__hash__word". This may be a problem that can be ignored.

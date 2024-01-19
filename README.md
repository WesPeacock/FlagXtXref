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

## To Do
- keep track of the original line numbers of the start of the records (i.e. EOL + previous special EOLs

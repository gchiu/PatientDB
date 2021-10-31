Rebol []

; read all the files into the files database

digit: charset [#"0"- #"9"]
alpha: charset [#"a" - #"z" #"A" - #"Z"]
nhi-rule: [3 alpha 4 digit]
filename-rule: [nhi-rule "-" some alpha "-202" 5 digit "-" digit ".txt"]

dbase: open odbc://patients
port: first dbase

foreach file letters: read %patients/ [
    ; if the filename matches the filename-rule, then check to see if it is in the database
    ; if not, then add it
    ffile: form file
    if parse ffile filename-rule [
        print ffile
    ]
]

close dbase

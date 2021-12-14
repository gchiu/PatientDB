Rebol []

; read all the files into the files database

if not value? 'dir [ ;'
    print "Need to set dir, the directory to process"
    halt
]

digit: charset [#"0"- #"9"]
alpha: charset [#"a" - #"z" #"A" - #"Z"]
nhi-rule: [3 alpha 4 digit]
filename-rule: [nhi-rule "-" some alpha "-20" 6 digit "-" digit ".txt"] ; only do from year 2000 onwards

dbase: open odbc://patients
port: first dbase

; path: %2021/2021/October/
;path: %2021/2021/September/
;path: %2021/2021/January/
;path: %test-parser/
; dir: %2021/2021/October/

foreach file read dir [
    ?? file
    ; if the filename matches the filename-rule, then check to see if it is in the database
    ; if not, then add it
    ffile: form file
    if parse ffile filename-rule [
        print ffile
        insert port [{select * from files where filename =(?)} ffile]
        if none? pick port 1 [
            insert port [{insert into files (filename) values (?)} ffile]
        ]
    ]
]

close dbase

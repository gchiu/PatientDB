Rebol []

is?: func [word][
    null? any ['~attached~ = binding of word, unset? word]
]

isn't?: func [word][not is? word]

; read all the files into the files database
if isn't? 'dir [
    print "Need to set dir, the directory to process"
    halt
]

digit: charset [#"0"- #"9"]
alpha: charset [#"a" - #"z" #"A" - #"Z"]
nhi-rule: [3 alpha 4 digit]
filename-rule: [nhi-rule "-" some alpha "-20" 6 digit "-" digit ".txt"] ; only do from year 2000 onwards

dbase: open odbc://rebol-firebird
port: odbc-statement-of dbase

show-sql?: true

sql-execute: specialize :odbc-execute [; https://forum.rebol.info/t/1234
	statement: port
	verbose: if show-sql? [#]
]

for-each file read dir [
	?? file
    ; if the filename matches the filename-rule, then check to see if it is in the database
    ; if not, then add it
    ffile: form file
    if parse? ffile filename-rule [
        print ffile
        sql-execute unspaced [{select * from files where filename =(} ffile ")"]
        if none? copy port [
            sql-execute unspaced [{insert into files (filename) values (} ffile {)}]
        ]
    ]
]

close dbase

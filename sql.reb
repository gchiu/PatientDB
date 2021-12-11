Rebol [
    type: module
    exports: [sql-execute port dbase dump-table]
]

; dbase: open join odbc://rebol-firebird ";UID=test;PWD=test-password"
; dbase: open odbc://patients
dbase: open odbc://test
port: odbc-statement-of dbase
show-sql?: true

sql-execute: specialize :odbc-execute [; https://forum.rebol.info/t/1234
	statement: port
	verbose: if show-sql? [#]
]

dump-table: func [table [word!]][
    sql-execute join {select * from } table
    print spaced ["Dumping" table]
    for-each record copy port [
        dump record
    ]
]

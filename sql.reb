Rebol [
    type: module
    exports: [sql-execute port dbase dump-table dsn digit alpha]
]

dsn: "rebol-firebird;UID=test;PWD=test-password"

;  dsn: "test"
; dsn: "patients"

digit: charset [#"0" - #"9"]
alpha: charset [#"a" - #"z" #"A" - #"Z"]

print ["Opening dsn:" dsn]
; dbase: open join odbc:// dsn

dbase: open [
    scheme: 'odbc
    user: '
    pass: ~no-user~
    host: "rebol-firebird;UID=test;PWD=test-password"
    port-id: '
    path: '
    tag: '
    ref: odbc://rebol-firebird;UID=test;PWD=test-password
]

port: odbc-statement-of dbase
show-sql?: true

sql-execute: specialize :odbc-execute [; https://forum.rebol.info/t/1234
    statement: port
    verbose: if show-sql? [#]
]

dump-table: func [table [word!]][
    ;
    ; Note: Table names cannot be used in parameterized queries:
    ;
    ; https://stackoverflow.com/q/1208442/
    ;
    ; For the moment, the ^META parameter just injects the word directly as
    ; a string.  At minimum this should need something like SQL-EXECUTE/UNSAFE.
    ;
    sql-execute [SELECT * FROM ^table]

    print ["Dumping" table]
    for-each record copy port [
        dump record
    ]
]

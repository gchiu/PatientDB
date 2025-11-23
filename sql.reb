Rebol [
    type: module
    exports: [sql-execute port dbase dump-table dsn digit alpha]
]

dsn: "rebol-firebird;UID=test;PWD=test-password"

; dsn: "tests"
; dsn: "patients"

digit: charset [#"0" - #"9"]
alpha: charset [#"a" - #"z" #"A" - #"Z"]

print ["Opening dsn:" dsn]
dbase: open join odbc:// dsn

port: odbc-statement-of dbase
show-sql?: okay

sql-execute: specialize odbc-execute/ [  ; https://forum.rebol.info/t/1234
    statement: port
    verbose: if show-sql? [okay]
]

dump-table: func [table [word!]][
    ;
    ; Note: Table names cannot be used in parameterized queries:
    ;
    ; https://stackoverflow.com/q/1208442/
    ;
    ; For the moment, the $[table] parameter just injects the word directly as
    ; a string...text is not allowed without using <!>
    ;
    sql-execute [SELECT * FROM $[table]]

    print ["Dumping" table]
    for-each 'record copy port [
        dump record
    ]
]

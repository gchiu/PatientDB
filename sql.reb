Rebol [
    type: module
    exports: [sql-execute port dbase dump-table dsn digit alpha]
]

dsn: "rebol-firebird;UID=test;PWD=test-password"

;  dsn: "test"
;  dsn: "patients"

digit: charset [#"0" - #"9"]
alpha: charset [#"a" - #"z" #"A" - #"Z"]

print spaced ["Opening dsn:" dsn]
dbase: open join odbc:// dsn
port: odbc-statement-of dbase
show-sql?: true

sql-execute: specialize :odbc-execute [; https://forum.rebol.info/t/1234
	statement: port
	verbose: if show-sql? [#]
]

dump-table: func [table [word!]][
    sql-execute [{select * from} ^table]
    print spaced ["Dumping" table]
    for-each record copy port [
        dump record
    ]
]

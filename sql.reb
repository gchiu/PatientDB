Rebol [
    type: module
    exports: [sql-execute port dbase]
]

dbase: open odbc://rebol-firebird
port: odbc-statement-of dbase
show-sql?: true

sql-execute: specialize :odbc-execute [; https://forum.rebol.info/t/1234
	statement: port
	verbose: if show-sql? [#]
]

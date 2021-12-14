Rebol [
    file: %check.reb
    purpose: {
        checks to make sure that the data in the tables is expected

    }

]

import %sql.reb

    dump-table 'patients
    dump-table 'files
    dump-table 'letters
    dump-table 'diagnoses
    dump-table 'medications

dbid: 1
sql-execute [SELECT name FROM medications WHERE active = 'F' AND id = @dbid]
result: copy port
for-each r result [
    dump r
]

sql-execute {select count(*) from medications}  ; !!! how to dialect COUNT(*)?
result: copy port
dump result
if result.1.1 <> 21 [
    fail "Not enough medications"
]

sql-execute {select count(*) from diagnoses}  ; !!! how to dialect COUNT(*)?
result: copy port
dump result
if result.1.1 <> 19 [
    fail "Not enough diagnoses"
]

Rebol [
    file: %check.reb
    purpose: {
        checks to make sure that the data in the tables is expected

    }

]

system.options.redbol-paths: true

import %sql.reb

    dump-table 'patients
    dump-table 'files
    dump-table 'letters
    dump-table 'diagnoses
    dump-table 'medications

sql-execute {select count(*) from medications}
result: copy port
dump result
if result/1/1 <> 21 [
    fail "Not enough medications"
]

sql-execute {select count(*) from diagnoses}
result: copy port
dump result
if result/1/1 <> 19 [
    fail "Not enough diagnoses"
]

dbid: 1
sql-execute [{select name from medications where active = 'F' and id =} ^dbid]
result: copy port
for-each r result [
    dump r
]

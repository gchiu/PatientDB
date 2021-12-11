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

sql-execute {select count(*) from diagnoses}
result: copy port
if result/1/1 <> 19 [
    fail "Not enough diagnoses"
]

sql-execute {select count(*) from medications}
result: copy port
if result/1/1 <> 21 [
    fail "Not enough medications"
]


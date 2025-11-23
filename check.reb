Rebol [
    file: %check.reb
    purpose: --[
        Checks to make sure that the data in the tables is expected.
    ]--
]

import %sql.reb

    dump-table 'patients
    dump-table 'files
    dump-table 'letters
    dump-table 'diagnoses
    dump-table 'medications

dbid: 1
sql-execute [SELECT name FROM medications WHERE active = -['F']- AND id = $dbid]
result: copy port
for-each 'r result [
    dump r
]

sql-execute -[select count(*) from medications]-  ; !!! how dialect COUNT(*)?
result: copy port
dump result
print ["number of medications:" result.1.1]
if result.1.1 <> 36 [
    panic "Not enough medications"
]

sql-execute -[select count(*) from diagnoses]-  ; !!! how dialect COUNT(*)?
result: copy port
print ["number of diagnoses:" result.1.1]

if result.1.1 <> 44 [
    panic "Not enough diagnoses"
]

rebol [
    file: %dlv5129.reb
]

import %sql.reb

sql-execute "select id from nhilookup where nhi = 'DLV5219'"
result: copy port
id: result.1.1

sql-execute [DELETE FROM diagnoses WHERE nhi = $id]
sql-execute [DELETE FROM medications WHERE nhi = $id]

; !!! Open dialect questions for date and string literals.
;
sql-execute "update files set done = FALSE where filename = 'DLV5219-GChiu-20211204-1.txt'"
sql-execute ["delete from letters where nhi =" $id "and cdate = '4-Dec-2021'"]

print "Removed last letter for DLV5219"

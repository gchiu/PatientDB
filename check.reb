Rebol [
    file: %check.reb
    purpose: {
        checks to make sure that the data in the tables is expected

    }

]

import %sql.reb

; lets see what files we have 

sql-execute {select * from files}
result: copy port
for-each record result [
    dump record
]

sql-execute {select id, clinicians, nhi, cdate, checksum from letters}
result: copy port
for-each record result [
    dump record
]

comment [{ ; NHI ABC9931
Psoriatic arthritis 
- CCP > 300, RF +ve
E-cadherin mutation carrier. 
- Sister died with stomach cancer aged 38 
- Has declined prophylactic gastrectomy 
Medications: 
Leflunomide 20mg daily 
Methotrexate 20mg once weekly 
Folic Acid 0.8mg daily 
Prednisone 7.5mg daily *reducing to 6mg and taper 1mg per month*
}]

sql-execute {select * from nhilookup}
probe copy port

nhi: "ABC9931"
sql-execute replace {select id from NHILOOKUP where nhi = '?'} "?" nhi

result: copy port
dump result
for-each record result [
    nhi: record/1
    dump-table 'diagnoses
    dump-table 'medications
]

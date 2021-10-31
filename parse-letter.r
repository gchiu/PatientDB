Rebol [

    notes: {parse the letters to extract name, nhi, drug information etc}
]

dbase: open odbc://patients
port: first dbase

insert port [{select id, filename from files where done = (?)} false]
foreach record copy port [
    fileid: record/1
    filename: record/2
    nhi: copy/part filename 7
    parse filename 


]

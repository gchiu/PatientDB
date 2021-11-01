Rebol [

    notes: {parse the letters to extract name, nhi, drug information etc}
]

dbase: open odbc://patients
port: first dbase

dir: %patients/

; get all the clinicians first
insert port {select id, surname from clinicians}
clinicians: copy []
foreach c copy port [
    append clinicians reduce [c/2 c/1]
]
; Chiu 1 Elasir 2
probe clinicians


digit: charset [#"0"- #"9"]
alpha: charset [#"a" - #"z" #"A" - #"Z"]
nhi-rule: [3 alpha 4 digit]
filename-rule: [nhi-rule "-" some alpha "-202" 5 digit "-" digit ".txt"]

insert port [{select id, filename from files where done = (?)} false]
foreach record copy port [
    fileid: record/1
    filename: record/2
    nhi: uppercase copy/part filename 7
    current-doc: none
    if parse filename [NHI "-" copy clinician some alpha thru "-" copy ldate 8 digit "-" to ".TXT" to end][
        ; GChiu, Elasir
        foreach [doc id] clinicians [
            if find clinician doc [
                current-doc: id
                break
            ]
        ]
        either current-doc [
            ; convert ldate to a proper date
            parse ldate [copy year 4 digit copy month 2 digit copy day 2 digit]
            ldate: to date! rejoin [day "-" month "-" year]
            print reform ["clinician id is " current-doc]
            print reform ["clinic letter date is " ldate]
            ; now read the letter to parse the contents
            contents: read join dir filename
            probe contents
            halt
        ][
            ; no doc found, skip this letter
        ]
    ]
]

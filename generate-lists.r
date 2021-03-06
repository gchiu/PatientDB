Rebol [
    author: "Graham Chiu"
    date: 4-Nov-2021
    notes: {pullls patient details on certain drugs or drug combinations and generates pipe delimited files which can be read into
        Excel or OpenOffice. Use these spreadsheets to generate letters to patients.
    }
]

; NHI Clinic-Date First-Name Surname Street1 Street2 Town Drug1 Dose1 Drug2 Dose2

dbase: open odbc://patients
port: first dbase

patient-ids: copy []

biologics: ["Upadacitinib" "Rinvoq" "Enbrel" "Etanercept" "Humira" "Adalimumab" "Rituximab" "Secukinumab" "Cosentyx" "Infliximab" "Remicade" "Tocilizumab"]

foreach drug biologics [
    insert port [{select nhi, letter, name, dosing from medications where name like (?) and active = 'T'} join drug "%"]
    foreach record copy port [
        append/only patient-ids record
    ]
]

immunos: ["Cyclophosphamde" "Cellcept" "Mycophenolate"]

foreach drug immunos [
    insert port [{select nhi, letter, name, dosing from medications where name like (?) and active = 'T'} join drug "%"]
    foreach record copy port [
        append/only patient-ids record
    ]
]

; now we need to generate ; NHI Clinic-Date First-Name Surname Street1 Street2 Town Drug1 Dose1 Drug2 Dose2
; patient-ids [ [id clinicdate medication dosing]]

patients: copy []

foreach record patient-ids [
    probe record
    insert port [{select fname, surname, street, street2, town from patients where nhi =(?)} record/1]
    rec: pick port 1
    insert rec record/1
    append rec reduce [record/2 record/3 record/4]
    ; now fetch their actual NHI
    insert port [{select NHI from NHILOOKUP where id = (?)} record/1]
    rec2: pick port 1
    insert rec rec2/1
    append/only patients rec
]

; XXX2622 DAVID XXXXX NN Pxxx Road R D nn Foxton 9-Jul-2021 Mycophenolate Mofetil  250mg BD

ssheet: copy [{NHI | IntID | FirstName | Surname | Street | Street2 | Town | ClinicDate | Medication | Dose^/}]

; do not send out more than one letter - contains formal NHIs
unique-list: copy []

foreach rec patients [
    if not find unique-list rec/1 [
        append unique-list rec/1
        append ssheet rejoin [ rec/1 "| " rec/2 "| " rec/3 "| " rec/4 "| " rec/5 "| " rec/6 "| " rec/7 "| " rec/8 "| " rec/9 "| " rec/10]
        append ssheet newline
    ]
]

write %biologics.csv ssheet

; now lets get the patients taking Leflunomide, Arava and Methotrexate together

methotrexate: copy []

insert port [{select nhi from medications where name like 'Metho%' and ACTIVE = 'T'}]
foreach id copy port [
    append methotrexate id
]

; let's convert all the ARAVA patients to LEFLUNOMIDE ;'

insert port {update medications set name = 'Leflunomide' where name like '%Arava%'}

Leflunomide: copy []
insert port [{select nhi from medications where name like 'Leflu%' and ACTIVE = 'T'}]
foreach id copy port [
    append Leflunomide id
]

; insert port [{select nhi from medications where name like 'Arava%' and ACTIVE = 'T'}]
; foreach id copy port [
;    append Leflunomide id
; ]

MTX-LEF: unique intersect leflunomide methotrexate

mtx-lef-patients: copy []

; now get the people
foreach record MTX-LEF [
    probe record
    insert port [{select fname, surname, street, street2, town from patients where nhi =(?)} record]
    rec: pick port 1
    insert rec record
    ; now fetch their actual NHI
    insert port [{select NHI from NHILOOKUP where id = (?)} record]
    rec2: pick port 1
    insert rec rec2/1
    ; get their clinic date for the mtx
    insert port [{select letter, name, dosing from medications where nhi =(?) and active = 'T' and name like 'Metho%'} record]
    rec2: pick port 1
    append rec rec2
    insert port [{select name, dosing from medications where nhi =(?) and active = 'T' and name like 'Leflu%'} record]
    rec2: pick port 1
    append rec rec2
    insert port [{select name, dosing from medications where nhi =(?) and active = 'T' and name like 'Arava%'} record]
    rec2: pick port 1
    append rec rec2
    append/only mtx-lef-patients rec
]


ssheet: copy [{NHI | IntID | FirstName | Surname | Street | Street2 | Town | ClinicDate | Methotrexate | Dose | Leflunomide | dose ^/}]

foreach rec mtx-lef-patients [
    if not find unique-list rec/1 [
        append unique-list rec/1
        append ssheet rejoin [ rec/1 "| " rec/2 "| " rec/3 "| " rec/4 "| " rec/5 "| " rec/6 "| " rec/7 "| " rec/8 "| " rec/9 "| " rec/10 "| " rec/11 "| " rec/12]
        append ssheet newline
    ]
]

write %metho-lef.csv ssheet

show-consults: func [ id
    /local consults dates lo fname surname nhilabel clin
][
    dates: copy [] lo: none fname: copy "" surname: copy "" nhilabel: copy "" clin: copy ""
    sf: none
    attempt [id: to integer! id]
    either not integer? id [
        ; passed as word! string!
        id: uppercase form id
        if 7 <> length? id [
            print "invalid NHI number"
            halt
        ]
        nhiid: id ;keep that
        insert port [{select id from NHILOOKUP where nhi = (?)} nhiid]
        id: pick port 1
        either none? id [
            print "NHI not found"
            halt
        ][
            id: id/1
        ]
    ][
        insert port [{select nhi from NHILOOKUP where id = (?)} id]
        if none? rec: pick port 1 [
            print "Patient not found"
            halt
        ]
        nhiid: rec/1
    ]

    insert port [{select fname, surname, dob from patients where nhi =(?)} id]
    if none? rec: pick port 1 [
        print "Patient not found"
        halt
    ]
    fname: rec/1
    surname: rec/2
    dob: form rec/3

    consults: copy [] dates: copy []
        insert port [{select cdate, clinicians, dictation from letters where nhi = (?)} id]
        foreach record copy port [
            append consults record ; cdate clinicians dictation
            append dates record/1
        ]
        lo: layout [across
            label black "FirstName:" fnamefld: field fname label black "Surname:" surnamefld: field surname
            label black "DOB:" dobfld: field dob 80 label black "NHI:" nhilabel: field nhiid 80 return
            label black "Clinic Date:" clindatefld: field 80 label black "Clinician:" clin: field "" return
            dates: text-list 120x650 data dates [
                sdate: first dates/picked
                txt: first next next find consults sdate
                letter/text: txt show letter
                clinician: select consults sdate
                insert port [{select surname from clinicians where id = (?)} clinician]
                rec: pick port 1
                clin/text: form rec/1
                show clin
                clindatefld/text: sdate
                show clindatefld
            ]
            letter: area "" wrap 800x650
            ; sf: scroller 20x650 sf letter
        ]
        view lo
]

do %show-consults.r

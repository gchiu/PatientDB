Rebol [
    notes: {pull up all patients on a certain drug}

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
    append rec reduce [record/2 record/3 record/4]
    ; now fetch their actual NHI
    insert port [{select NHI from NHILOOKUP where id = (?)} record/1]
    rec2: pick port 1
    insert rec rec2/1
    append/only patients rec
]

; XXX2622 DAVID XXXXX NN Pxxx Road R D nn Foxton 9-Jul-2021 Mycophenolate Mofetil  250mg BD

ssheet: copy [{NHI | FirstName | Surname | Street | Street2 | Town | ClinicDate | Medication | Dose^/}]
unique-list: copy []

foreach rec patients [
    if not find unique-list rec/1 [
        append unique-list rec/1
        append ssheet rejoin [ rec/1 "| " rec/2 "| " rec/3 "| " rec/4 "| " rec/5 "| " rec/6 "| " rec/7 "| " rec/8 "| " rec/9 ]
        append ssheet newline
    ]
]

write %biologics.csv ssheet

Rebol [
    notes: {pull up all patients on a certain drug}

]

; NHI Clinic-Date First-Name Surname Street1 Street2 Town Drug1 Dose1 Drug2 Dose2

dbase: open odbc://patients
port: first dbase

patient-ids: copy []

biologics: ["Updacit" "Rinvoq" "Enbrel" "Etanercept" "Humira" "Adalimumab" "Rituximab" "Secukinumab" "Cosentyx" "Infliximab" "Remicade" "Tocilizumab"]

foreach drug biologics [
    insert port [{select nhi, letter from medications where name like (?) and active = 'T'} join drug "%"]
    foreach record copy port [
        append record drug
        append/only patient-ids record
    ]
]

immunos: ["Cyclophosphamde" "Cellcept" "Mycophenolate"]

foreach drug immunos [
    insert port [{select nhi, letter from medications where name like (?) and active = 'T'} join drug "%"]
    foreach record copy port [
        append record drug
        append/only patient-ids record
    ]
]

; now we need to generate ; NHI Clinic-Date First-Name Surname Street1 Street2 Town Drug1 Dose1 Drug2 Dose2
; patient-ids [ [id clinicdate medication]]

patients: copy []

foreach record patient-ids [
    probe record
    insert port [{select fname, surname, street, street2, town from patients where nhi =(?)} record/1]
    rec: pick port 1
    append rec [record/2 record/3]
    append/only patients rec
]


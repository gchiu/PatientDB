Rebol [
    notes: {pull up all patients on a certain drug}

]

; NHI Clinic-Date First-Name Surname Street1 Street2 Town Drug1 Dose1 Drug2 Dose2

dbase: open odbc://patients
port: first dbase

patient-ids: copy []

biologics: ["Updacit" "Enbrel" "Etanercept" "Humira" "Adalimumab" "Rituximab" "Secukinumab" "Cosentyx" "Infliximab" "Remicade" "Tocilizumab"]

foreach biologic biologics [
    insert port [{select nhi, letter from medications where name like (?) and active = 'T'} join biologic "%"]
    foreach record copy port [
        append/only patients-ids record
    ]
]

Rebol []

if not value? 'dbase [ ;'
    dbase: open odbc://patients
    port: first dbase
]

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
            panel [
                below
                dx: text-list 250x305 data "" 
                rx: text-list 250x350 data ""

            ]
        ]
        view lo
]


Rebol [
    file: %fetch-record.r
    Author: "Graham Chiu"
    Date: 12-Nov-2021
]

dbase: open odbc://patients
port: first dbase

; should be passing ["NHInnnn"] in system.options.args

alpha: charset [#"a" - #"z" #"A" - #"Z"]
digit: charset [#"0" - #"9"]
nhi-rule: [3 alpha 4 digit]

either none? system/options/args [
    write %temp.txt "ERR: No parameters provided"
    NHI: "LZS6558"; "DLV5219"
] [
    ; print "has parameter"
    NHI: uppercase first system/options/args
    ; ?? NHI
]

either parse nhi nhi-rule [
    insert port [{select id from NHILOOKUP where nhi = (?)} nhi]
    either rec: copy port [
        if empty? rec [
            write %temp.txt rejoin ["ERR: NHI of {" nhi "} not found"]
            quit
        ]
        ?? rec
        dbid: rec/1/1
        ; we have the id of the patient in the patients table, so let us get the demographics
        insert port [{select fname, surname, dob, gpname, gpcentname, phone, mobile, street from patients where nhi =(?)} dbid]
        print "after insert port"
        rec: copy port
        either not empty? rec [
            print "we have the demographics"
            rec: rec/1
            patient-o: make object! compose [
                fname: rec/1
                surname: rec/2
                dob: rec/3
                gpname: rec/4
                gpcentname: rec/5
                dbid: (dbid)
                nhi: (nhi)
                phone: rec/6 mobile: rec/7
                street: rec/8
                medications: diagnoses: dmards: consults: dates: none
            ]
            ; now let us get the number of medications
            medications: copy []
            insert port [{select name, dosing from medications where active = 'T' and nhi =(?)} dbid]
            rec: copy port
            if not empty? rec [
                foreach r rec [
                    append medications rejoin [r/1 " " r/2]
                ]
            ]
            patient-o/medications: unique medications
            ; diagnoses
            diagnoses: copy []
            insert port [{select diagnosis from diagnoses where nhi =(?)} dbid]
            rec: copy port
            if not empty? rec [
                foreach r rec [
                    append diagnoses r/1
                ]
            ]
            dmards: copy []
            insert port [{select name from medications where active = 'F' and nhi =(?)} dbid]
            rec: copy port
            if not empty? rec [
                foreach r rec [
                    append dmards r/1
                ]
            ]
            patient-o/dmards: unique dmards
            patient-o/medications: unique medications
            patient-o/diagnoses: unique diagnoses

            rdates: copy [] dates: copy [] consults: copy []
            insert port [{select id, cdate, clinicians, dictation from letters where nhi = (?) order by cdate DESC} dbid]
            foreach record copy port [
                append/only consults record ; id cdate clinicians dictation
                ; append rdates rejoin [next form 100000 + record/1 " " record/2]
                append dates form record/2
            ]
            ; foreach date sort rdates [
            ;    append dates form date
            ; ]
            patient-o/dates: dates
            patient-o/consults: consults
            out: copy "Red []^/^/patient-o: "
            ; probe out
            append out mold patient-o
            write %patient.red out
            write %temp.txt "OK"
        ] [
            write %temp.txt "ERR: NHI is not in database yet"
        ]
    ] [
        write %temp.txt "ERR: NHI is not in database yet"
    ]
][
    write %temp.txt "ERR: NHI invalid format"
]
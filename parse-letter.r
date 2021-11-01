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

space: #" "
digit: charset [#"0"- #"9"]
dob-rule: [2 digit "." 2 digit "." 4 digit]
alpha: charset [#"a" - #"z" #"A" - #"Z"]
name-rule: charset [#"a" - #"z" #"A" - #"Z" #"-" #"'"]
uc: charset [#"A" - #"Z"]
nhi-rule: [3 alpha 4 digit]
filename-rule: [nhi-rule "-" some alpha "-202" 5 digit "-" digit ".txt"]
months: ["January" "February" "March" "April" "May" "June" "July" "August" "September" "October" "November" "December"]
phone-rule: [["P:" | "Ph:"] space copy phone some digit]
mobile-rule: ["M:" space copy mobile some digit]

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
            longdate: rejoin [day " " pick months to integer! month " " year]
            ; now read the letter to parse the contents
            contents: read join dir filename
            probe contents
            ck: checksum/secure contents
            lines: deline/lines contents ; split into lines and parse each line
            surname: fname: sname: mobile: phone: dob: fp: email: none
            address: copy []
            mode: 'date ;'
            foreach line lines [
                trim/head/tail line
                if not empty? line [
                    switch mode [
                        date [
                            if find line longdate [
                                ; now we are in the header
                                mode: 'name ;'
                            ]
                        ]

                        name [ ;look for patient name next eg. XXXX, XXXX XXXX 
                            ?? line
                            either parse/all line [uc some name-rule ", " copy fname some name-rule opt [" " copy sname to end] end ][
                                ; we have surnames, and first names
                                parse/all line [copy surname to ","]
                                ?? surname ?? fname ?? sname
                                surname: uppercase surname
                                fname: uppercase fname
                                if sname [sname: uppercase sname]
                                mode: 'nhi ;'
                            ][
                                print ["can't find name in line " line ]
                            ]
                        ]

                        nhi [; confirm nhi matches that from the filename
                            if parse line ["NHI: " copy letter-nhi nhi-rule][
                                either letter-nhi <> nhi [
                                    print "Mismatch on file NHI and Letter NHI"
                                    break
                                ][
                                    mode: 'address ;'
                                ]
                            ]
                        ]

                        address [; start capturing address lines and dob mixed in together, terminated by finding GP:
                            case [
                                parse line ["DOB: " copy dob dob-rule][
                                    replace/all dob "." "-"
                                    dob: to date! dob
                                ]

                                parse line ["GP:" copy fp to end][
                                    mode: 'fp ;' got the FP name
                                ]

                                parse line [some [phone-rule | mobile-rule]][
                                    ?? mobile
                                    ?? phone
                                ]
                                
                                find line "@" [email: copy line]

                                true [; just address lines
                                    append/only address line
                                ]
                            ]
                        ]
                    ]
                ]
            ]
            ?? mode
            ?? longdate
            ?? nhi
            ?? surname
            ?? fname
            ?? sname
            ?? address
            ?? mobile
            ?? phone
            ?? email
            ?? fp
            ?? current-doc
            halt
        ][
            ; no doc found, skip this letter
        ]
    ]
]

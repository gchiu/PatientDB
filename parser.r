Red [
    title: "letter parser"
    notes: {used in a batch script to parse all letters in the database}
]

; contents: read to-rebol-file filename: "2021\2021\October\GJS2525-HElasir-20211006-1.txt"
; contents: read rfn: to-rebol-file filename: filename: "2021\2021\October\DLV5219-GChiu-20211030-1.txt"
contents: read rfn: to-rebol-file filename: filename: "D:\2020\2020\November\CLU3365-HElasir-20201124-1.txt"
mode: 'date ;'
; nhi: "CLU3365" ;"DLV5219" ; "GJS2525"
address: copy []
fpaddress: copy []
diagnosis-detail: copy ""
diagnoses: copy []
dmards: copy []
medications: copy []


space: #" "
whitespace: charset [#" " #"^-"]
digit: charset [#"0" - #"9"]
areacode-rule: [4 digit]
dob-rule: [2 digit "." 2 digit "." 4 digit]
alpha: charset [#"a" - #"z" #"A" - #"Z"]
name-rule: charset [#"a" - #"z" #"A" - #"Z" #"-" #"'" #" "]
fname-rule: [some alpha #"-" some alpha | some alpha]
uc: charset [#"A" - #"Z"]
nhi-rule: [3 alpha 4 digit]
filename-rule: [nhi-rule "-" some alpha "-20" 6 digit "-" digit ".txt"]
months: ["January" "February" "March" "April" "May" "June" "July" "August" "September" "October" "November" "December"]
phone-rule: [["P:" | "Ph:"] space copy phone some digit]
mobile-rule: ["M:" space copy mobile some digit]
drugname-rule: [some [some alpha opt space]]

diagnosis-rule: complement charset [#"^-"]

parse filename [thru "\" thru "\" thru "\" copy month to "\" 1 skip copy nhi to "-" thru "-" thru "-" copy year 4 digit 2 skip copy day
    2 digit (day: to integer! day) to end]

longdate: rejoin [day " " month " " year]
?? longdate
el: 1
oldmode: none

;=======parser starts
mode: 'date
foreach line deline/lines contents [; split into lines and parse each line
    trim/head/tail line
    either empty? line [
        case [

            all [mode = 'medication not empty? medications] [
                either oldmode = 'page-2-medications [

                ] [
                    print "empty line, in medication mode, and not empty medications"
                    mode: 'page-2-medications
                ]
            ]

            all [mode = 'diagnoses not empty? diagnoses] [
                either oldmode = 'page-2-diagnoses [] [
                    mode: 'page-2-diagnoses
                ]
            ]

            mode = 'name []

            all [mode = 'dmards not empty? dmards] [mode: 'finish]
        ]

    ] [; not an empty line

        if find/part line "VITALS" 6 [
            mode: 'finish
        ]

        switch mode [
            date [
                if find line longdate [
                    ; now we are in the header
                    mode: 'name ;'
                ]
            ]

            comment {

BLOGGS, SIMON PETER
NHI: DLV9215
}


            name [;look for patient name next eg. XXXX, XXXX XXXX or XXX XXX, XXX XXX
                either parse/all line [uc some name-rule ", " copy fname fname-rule opt [" " copy sname to end] end] [
                    ; we have surnames, and first names
                    parse/all line [copy surname to ","]
                    ?? surname ?? fname ?? sname
                    surname: uppercase surname
                    fname: uppercase fname
                    if sname [sname: uppercase sname]
                    mode: 'nhi ;'
                ] [
                    print ["can't find name in line " line]
                    mode: 'abandon ;' maybe try alternate name parser
                ]
            ]

            nhi [; confirm nhi matches that from the filename
                if parse line ["NHI: " copy letter-nhi nhi-rule] [
                    either letter-nhi <> nhi [
                        print "Mismatch on file NHI and Letter NHI"
                        break
                    ] [
                        mode: 'address ;'
                    ]
                ]
            ]

            comment {
Flat ..

GP: Dr A E Hughes

}

            address [; start capturing address lines and dob mixed in together, terminated by finding GP:
                line: copy/part line 60 ; let us trim anything to the right
                case [
                    parse line ["DOB: " copy dob dob-rule] [
                        replace/all dob "." "-"
                        dob: to date! dob
                    ]

                    parse/all line ["GP: " copy fp to end] [
                        fpname: last parse fp none
                        mode: 'fp ;' got the FP name
                    ]

                    parse/all line [some [phone-rule | mobile-rule | space] end] []

                    find line "@" [email: copy line]

                    true [; just address lines
                        ; get area code out
                        rline: reverse copy line
                        if parse/all rline [copy areacode areacode-rule space copy line to end] [
                            areacode: reverse areacode
                            line: reverse line
                        ]
                        append/only address line
                    ]
                ]
            ]

            comment {
Dr A E Hughes    cc:    ENT Department, PNH
Otaihape Health
PO Box 123
TAIHAPE
}

            fp [; extract fp address
                case [
                    find/part line "Dear" 4 [
                        mode: 'end-salutation ;'
                    ]

                    find/part line "INTERNAL" 8 [
                        ; internal referral
                        mode: 'finish ;'
                    ]

                    true [
                        if not find line fpname [
                            ; if there are tabs in the line, it's from a copy to someone else
                            ; eg {Kauri HealthCare^-^-^-^Whanganui Hospital} ;'
                            if find line #"^-" [
                                parse line [copy line to #"^-"]
                            ]
                            append fpaddress line
                        ]
                    ]

                ]
            ]

            comment {
Dear Colleague

Diagnoses:
}
            end-salutation [
                if find/part line "Diagnos" 7 [
                    mode: 'diagnosis ;'
                ]
                if find/part line "INTERNAL" 8 [
                    print "internal referral"
                    mode: 'finish ;'
                ]
            ]

            diagnosis [
                if any [find/part line "Page " 5 find/part line "…" 1] [
                    print "switching to page-2-diagnoses"
                    mode: 'page-2-diagnoses
                ]
                either find/part line "Medicat" 7 [
                    mode: 'medication ;'
                    if not empty? diagnosis-detail [; catch end of list issue
                        append/only diagnoses reduce [trim/tail diagnosis-detail]
                        diagnosis-detail: copy ""
                    ]
                ] [
                    ; check to see if leading number eg. 1. or -, the former to be removed and the latter indicates details
                    ; 1.     Psoriatic Arthritis
                    ;         a. CCP+ve
                    ;        b) RF-ve
                    ; Anti-CCP +ve rheumatoid arthritis
                    case [
                        parse/all line [any whitespace "-" any whitespace copy dline to end | ; this is diagnosis detail
                            any whitespace some alpha "." any whitespace copy dline to end | ; so is this
                            any whitespace some alpha ":" any whitespace copy dline to end | ; so is this
                            any whitespace alpha ")" any whitespace copy dline to end ; a), b)^- ; so is this
                        ] [
                            if dline [
                                trim/head/tail dline
                                append diagnosis-detail join dline "; "
                            ]
                        ]
                        parse/all line [
                            some digit "." any whitespace copy line to end | ; where the diagnosis starts with a digit
                            copy line some diagnosis-rule to end
                        ] [
                            ; submode: 'gotdx ;'
                            if line [; sometimes blank after a number!
                                trim/head/tail line
                                ; now add the details as a block
                                either not empty? diagnosis-detail [
                                    append/only diagnoses reduce [trim/tail diagnosis-detail]
                                    diagnosis-detail: copy ""
                                ] [if not empty? diagnoses [append/only diagnoses copy [""]]]
                                append diagnoses line
                            ]
                        ]
                    ]
                    ; append diagnoses line
                ]
            ]

            comment {
Page 2
XXXXX, XXX XX
NHI: XXXXNNN
}
            page-2-medications [
                print reform ["In mode: " mode]
                ; ?? line
                case [
                    find/part line "NHI:" 4 [
                        mode: 'medication
                        oldmode: 'page-2-medications ;'
                    ]

                    all [50 < length? line not find line "mg"] [
                        mode: 'finish
                    ]
                ]
            ]

            page-2-diagnoses [
                if find/part line "NHI:" 4 [
                    mode: 'diagnoses ;'
                    oldmode: 'page-2-diagnoses ;
                ]
            ]

            medication [
                ; medications can spill into the next page
                ; ?? line
                case [
                    any [find/part line "Page " 5 find/part line "…" 1] [
                        print "switching to page-2-medications"
                        mode: 'page-2-medications
                    ]

                    any [
                        find line "MARDS"
                        find line "Previous Medications"
                        find line "Previous Medication"
                        find line "Previous DMARDS"
                        find line "Previous MARDS"
                        find line "DMARDS"
                        find line "DMARD History"
                        find line "Previous DMARD History"
                    ] [print "**************Found DMARD line**************"
                        mode: 'dmards
                    ] ;'

                    true [
                        append medications line
                    ]
                ]
            ]

            dmards [
                either any [find line "DMARD" find line "Previous" find line "Medications"] [
                ] [
                    append dmards line
                ]
            ]

            finish [
                print "Finished processing or no diagnoses/medications in this letter"
                break
            ]
        ]

    ]
]


;=============parser ends

print "**Medications**"
if empty? medications [print "None"]
foreach d medications [print d]

print "**Diagnoses**"
if empty? diagnoses [print "none"]
foreach d diagnoses [print d]

print "**DMARDS**"
if empty? dmards [print "none"]
foreach d dmards [print d]

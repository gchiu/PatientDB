Rebol [
    author: "Graham Chiu"
    date: 4-Nov-2021
    notes: {parse the letters (file names stored in files database) to extract name, nhi, drug information, GP etc
        30.11.2021 since this uses `pick` we have to use rebol2 and not ren-c at present. Updated to update medications
        06.12.2021 start the port to renc
        11.12.2021 ported to sql-execute syntax
    }
]

if any [blank? system.script.args empty? system.script.args] [
    ; use this as the testing directory with no args
    dir: %2021/2021/October/
] else [
    dir: dirize to file! system.script.args
    if dir = %/ [
        fail "Can't use in current directory"
    ]
    if not exists? dir [
        fail spaced ["dir" dir "does not exist"]
    ]
]

print "==================================in parse-letter.reb==================================="
; get all sql and obdc needed
import %sql.reb

debug: false

; get all the clinicians first
sql-execute {select id, surname from clinicians}
clinicians: copy []
for-each c copy port [
    append clinicians reduce [c.2 c.1]
]
; Chiu 1 Elasir 2
probe clinicians

; space: #" "
whitespace: charset [#" " #"^-"]
digit: charset [#"0" - #"9"]
areacode-rule: [4 digit]
dob-rule: [2 digit "." 2 digit "." 4 digit]
alpha: charset [#"a" - #"z" #"A" - #"Z"]
name-rule: charset [#"a" - #"z" #"A" - #"Z" #"-" #"'" #" "]
fname-rule: [some further alpha #"-" some further alpha | some further alpha]
uc: charset [#"A" - #"Z"]
nhi-rule: [3 alpha 4 digit]
filename-rule: [nhi-rule "-" some further alpha "-20" 6 digit "-" digit ".txt"] ; 2019, 2020, 2021
months: ["January" "February" "March" "April" "May" "June" "July" "August" "September" "October" "November" "December"]
phone-rule: [["P:" | "Ph:"] space copy phone some digit]
mobile-rule: ["M:" space copy mobile some further digit]
drugname-rule: [ 1 digit "-" some alpha opt space | some alpha "-" some alpha opt space | some [some alpha opt space]]
not-drug-rule: complement union union alpha whitespace digit

diagnosis-rule: complement charset [#"^-"]
; Anti-CCP +ve rheumatoid arthritis
; Chickenpox pneumonia (age 31 years) with residual granulomata seen on chest x-ray

cnt: 1 ; number of iterations in the current directory
checks: copy []
records: copy []

mismatch-nhi: 0
missing-files: 0

; get all the filenames where the file has not yet been processed
cmd: {select id, filename from files where done IS FALSE}
dump cmd
sql-execute cmd
; collect all the filenames
for-each record copy port [
    append/only records record
]

print ["Number of files needed to process:" length-of records]

find-clinician: func [clinician [text!]] [
    for-each [doc id] clinicians [
        if find clinician doc [
            return id
        ]
    ]
    return _
]

for-each record records [; records contains all id, filenames from files where flag done is false
    ?? record
    fileid: record.1
    print "::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
    print ["fileid" fileid]
    filename: record.2
    print ["filename" filename]
    print ["processing" filename]

    if exists? to file! join dir filename [
        ; append/only records record
        print ["Current file number:" cnt: me + 1]
        print ["Processing" filename]
        ; nhi: uppercase copy/part filename 7
        current-doc: _
        ; see if it matches the current filename format
        if parse? filename filename-rule [
            print ["Filename passed rule" filename]
            nhi: letter-nhi: _
            parse filename [copy nhi nhi-rule "-" copy clinician some further alpha thru "-" copy ldate 8 digit "-" to ".txt" to end]
            ; GChiu, Elasir
            if integer? current-doc: find-clinician clinician [
                ; convert ldate to a proper date
                dump ldate
                parse ldate [copy year 4 digit copy month 2 digit copy day 2 digit]
                ldate: to date! unspaced [day "-" month "-" year]
                print ["clinician id is" current-doc]
                print ["clinic letter date is" ldate]
                longdate: unspaced [to integer! day " " pick months to integer! month " " year]
                dump longdate

                surname: fname: sname: mobile: phone: dob: fp: email: areacode: fpname: _
                address: copy [] fpaddress: copy [] medications: copy [] diagnoses: copy [] dmards: copy []
                diagnosis-detail: copy ""

                ; now read the letter to parse the contents
                if e: error? trap [
                    contents: to text! deline read join dir filename
                ][
                    probe e
                    continue ; to next file as there's something wrong with this one
                ]
                if not find contents "Dear " [
                    ; no way to find when the medications finish so skip this file
                    continue ; to next file
                ]
                has-diagnoses?: has-medications?: false
                if any [find contents "Diagnosis" find contents "^/Diagnos" find contents "^MDiagnos"][
                    has-diagnoses?: true
                ]
                if any [find contents "Medication" find contents "^/Medicat" find contents "^MMedicat"][
                    has-medications?: true
                ]
                ;dump has-medications?
                ;dump has-diagnoses?
                ;probe contents
                ;halt
                ck: form checksum 'md5 contents ; we have the checksum to prevent us from processing the same file content twice
                if find checks ck [
                    ; meaning that another file has the same contents as this one during this run
                    print "checksum duplicate!"
                    ; halt
                ] else [
                    append checks ck ; and now start processing this letter
                    ; now check to see if the letters database has this letter or not
                    ; letters table holds files we have already processed
                    print "Preparing to sql-execute on 154"
                    sql-execute [SELECT id FROM letters WHERE checksum = @ck]
                    if empty? copy port [; okay not done yet so we can add it and then process it
                        print "aint done"
                        oldmode: _
                        ;==============parser starts
                        mode: 'date ;  date should always be found on the first line of each letter
                        for-each line deline/lines contents [; split into lines and parse each line
                            trim/head/tail line
                            dump line
                            dump mode
                            if empty? line [
                                case [
                                    all [mode = 'alternate-gp][
                                        mode: 'dear
                                    ]
                                    all [mode = 'medication not empty? medications] [
                                        if not equal? oldmode 'page-2-medications [
                                            print "empty line, in medication mode, and not empty medications"
                                            mode: 'page-2-medications
                                        ]
                                    ]

                                    all [mode = 'diagnoses not empty? diagnoses] [
                                        if not equal? oldmode 'page-2-diagnoses [
                                            mode: 'page-2-diagnoses
                                        ]
                                    ]

                                    mode = 'name [
                                        ; alternate format
                                    ]

                                    all [mode = 'dmards not empty? dmards] [print "empty line 165" mode: 'finish]

                                    mode = 'fp [
                                        if all [empty? diagnoses not empty? fpaddress][
                                            dump fpaddress
                                            print "line 169 finish"
                                            if not has-diagnoses? [
                                                mode: 'finish
                                            ]
                                        ]
                                    ]
                                ]

                            ] else [; not an empty line

                                if find/part line "VITALS" 6 [
                                    print "found vitals - going to finish 171"
                                    mode: 'finish
                                ]

                                switch mode [

                                    'dear [
                                        ; reached on the alternate pathway
                                        mode: 'name
                                    ]

                                    'date [
                                        if find line longdate [
                                            ; now we are in the header
                                            mode: 'name ;'
                                        ]
                                    ]

                                    'name [;look for patient name next eg. XXXX, XXXX XXXX or XXX XXX, XXX XXX
                                        if parse? line [uc some name-rule ", " copy fname fname-rule opt [" " copy sname to end] end] [
                                            ; we have surnames, and first names
                                            parse line [copy surname to ","]
                                            dump surname dump fname dump sname
                                            surname: uppercase surname
                                            fname: uppercase fname
                                            if sname [sname: uppercase sname]
                                            mode: 'nhi
                                        ] else [
                                            ;print unspaced ["can't find name in line " line]
                                            ;mode: 'abandon ;' maybe try alternate name parser
                                            ; alternate format with GP as first block
                                            if any [find/part line "Dr " 3 find/part  line "Prof " 4][
                                                mode: 'alternate-gp
                                                print "In PDF mode"
                                                ; remove anything after tabs to get rid of the ccs
                                                if find line "^-" [
                                                    line: copy/part line index? find line "^-"
                                                ]
                                                fpblock: split line space
                                                fpblockrev: reverse copy fpblock
                                                if fpblockrev.2 = "der" [
                                                    append fpblockrev.2: spaced [fpblock.2 fpblockrev.1]
                                                    remove fpblockrev
                                                ]
                                                if any [fpblockrev.2 = "van" fpblockrev.2 = "le"][
                                                    append fpblockrev.2: spaced [fpblock.2 fpblockrev.1]
                                                    remove fpblockrev
                                                ]
                                                fpname: first fpblockrev
                                                fptitle: first fpblock
                                                fpinits: _
                                                parse line compose [thru (fptitle) copy fpinits to (fpname)]
                                                if not blank? fpinits [trim fpinits]
                                                trim fpname
                                                trim fptitle
                                                dump fpname
                                                dump fptitle
                                                dump fpinits
                                            ] else [
                                                print unspaced ["can't find name in line " line]

                                                mode: 'abandon ;' maybe try alternate name parser
                                            ]
                                        ]
                                    ]

                                    'alternate-gp [; or is it a PDF format?
                                        ; fail "Reached alternate format"
                                        append fpaddress line

                                    ]

                                    'nhi [; confirm nhi matches that from the filename
                                        if parse? line ["NHI:" opt some space copy letter-nhi nhi-rule] [
                                            either letter-nhi <> nhi [
                                                print "Mismatch on file NHI and Letter NHI"
                                                mismatch-nhi: me + 1
                                                continue ; to next letter
                                            ] [
                                                mode: 'address ;'
                                            ]
                                        ]
                                    ]

                                    'address [; start capturing address lines and dob mixed in together, terminated by finding GP:
                                        print "In address mode of switch"
                                        line: copy/part line 60 ; let us trim anything to the right
                                        case [
                                            parse? line ["DOB: " copy dob dob-rule] [
                                                replace/all dob "." "-"
                                                dob: to date! dob
                                                dump dob
                                            ]

                                            parse? line ["GP: " copy fp to end] [
                                                fpname: last split fp space
                                                mode: 'fp ;' got the FP name
                                            ]

                                            parse? line [some [phone-rule | mobile-rule | space] end] [
                                                dump phone
                                                dump mobile
                                            ]

                                            find line "@" [
                                                email: copy line
                                                dump email
                                            ]

                                            true [; just address lines
                                                ; get area code out
                                                rline: reverse copy line
                                                if parse? rline [copy areacode areacode-rule space copy line to end] [
                                                    areacode: reverse areacode
                                                    line: reverse line
                                                ]
                                                append/only address line
                                            ]
                                        ]
                                    ]

                                    'fp [; extract fp address
                                        print "extracting fp address  298"
                                        case [
                                            find/part line "Diagnos" 7 [
                                                mode: 'diagnosis
                                            ]
                                            find/part line "Dear" 4 [
                                                print "switching to end salutation 304"
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

                                    'end-salutation [
                                        if find/part line "Diagnos" 7 [
                                            mode: 'diagnosis ;'
                                        ]
                                        if find/part line "INTERNAL" 8 [
                                            print "internal referral"
                                            mode: 'finish ;'
                                        ]
                                    ]

                                    'diagnosis [
                                        print "diagnosis mode 325"
                                        line: detab line
                                        dump line
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
                                                parse? line [
                                                    opt some whitespace "-" opt some whitespace copy dline to end | ; this is diagnosis detail
                                                    opt some whitespace "•" opt some whitespace copy dline to end | ; so is this
                                                    opt some whitespace some alpha "." opt some whitespace copy dline to end | ; so is this
                                                    opt some whitespace some alpha ":" opt some whitespace copy dline to end | ; so is this
                                                    opt some whitespace alpha ")" opt some whitespace copy dline to end ; a), b)^- ; so is this
                                                ] [
                                                    print "got a diagnosis"
                                                    dump dline
                                                    if dline [
                                                        trim/head/tail dline
                                                        append diagnosis-detail join dline "; "
                                                    ]
                                                ]
                                                parse? line [
                                                    ; need to trap those cases where the diagnoses are numerated and aren't bullets to the one above in which case there's no leading space
                                                    opt some digit "." opt some whitespace copy line to end |
                                                    some digit "." opt some whitespace copy line to end | ; where the diagnosis starts with a digit
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

                                    'page-2-medications [
                                        print ["In mode: " mode]
                                        ; ?? line
                                        case [
                                            find/part line "NHI:" 4 [
                                                mode: 'medication
                                                oldmode: 'page-2-medications ;'
                                            ]

                                            all [50 < length-of line not find line "mg"] [
                                                print "finish at 404"
                                                mode: 'finish
                                            ]
                                        ]
                                    ]

                                    'page-2-diagnoses [
                                        if find/part line "NHI:" 4 [
                                            mode: 'diagnoses ;'
                                            oldmode: 'page-2-diagnoses ;'
                                        ]
                                    ]

                                    'medication [
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
                                                print "added to medications"
                                            ]
                                        ]
                                    ]

                                    'dmards [
                                        either any [find line "DMARD" find line "Previous" find line "Medications"] [
                                        ] [
                                            append dmards line
                                        ]
                                    ]

                                    'finish [
                                        print ":::::::::::::::::::::::::::Finished processing this letter 460"
                                        print ["Medications:" form length-of medications]
                                        print ["Diagnoses:" form length-of diagnoses]
                                        dump medications
                                        for-each medication medications [
                                            print medication
                                        ]
                                        dump diagnoses
                                        for-each [diagnosis detail] diagnoses [
                                            print ["dx:" diagnosis "detail:" detail]
                                        ]
                                        dump diagnosis-detail
                                        dump dmards
                                        break
                                    ]
                                ]
                            ] ; end of test for empty line
                        ] ; end of loop through each line of contents
                        ;==========parser ends

                        if debug [
                            ?? mode
                            ?? longdate
                            ?? nhi
                            ?? surname
                            ?? fname
                            ?? sname

                            mode: 'date
                            for-each line deline/lines contents [; split into lines and parse each line
                                trim/head/tail line
                                either empty? line [
                                    case [

                                        all [mode = 'medication not empty? medications] [
                                            either oldmode: 'page-2-medications [] [
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

                                        all [mode = 'dmards not empty? dmards] [print "finish at 494" mode: 'finish]
                                    ]

                                ] [; not an empty line

                                    if find/part line "VITALS" 6 [
                                        print "Found vitals - going to finish - 486"
                                        mode: 'finish
                                    ]

                                    switch mode [
                                        'date [
                                            if find line longdate [
                                                ; now we are in the header
                                                mode: 'name ;'
                                            ]
                                        ]
                                        'name [;look for patient name next eg. XXXX, XXXX XXXX or XXX XXX, XXX XXX
                                            either parse? line [uc some name-rule ", " copy fname fname-rule opt [" " copy sname to end] end] [
                                                ; we have surnames, and first names
                                                parse line [copy surname to ","]
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

                                        'nhi [; confirm nhi matches that from the filename
                                            if parse? line ["NHI: " copy letter-nhi nhi-rule] [
                                                either letter-nhi <> nhi [
                                                    print "Mismatch on file NHI and Letter NHI"
                                                    break
                                                ] [
                                                    mode: 'address ;'
                                                ]
                                            ]
                                        ]

                                        'address [; start capturing address lines and dob mixed in together, terminated by finding GP:
                                            line: copy/part line 60 ; let us trim anything to the right
                                            case [
                                                parse? line ["DOB: " copy dob dob-rule] [
                                                    replace/all dob "." "-"
                                                    dob: to date! dob
                                                ]

                                                parse? line ["GP: " copy fp to end] [
                                                    fpname: last parse fp none
                                                    mode: 'fp ;' got the FP name
                                                ]

                                                parse? line [some [phone-rule | mobile-rule | space] end] []

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

                                        'fp [; extract fp address
                                            print "Fp mode in switch"
                                            case [
                                                find/part line "Dear" 4 [
                                                    print "end salutation mode 569"
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

                                        'end-salutation [
                                            if find/part line "Diagnos" 7 [
                                                mode: 'diagnosis ;'
                                            ]
                                            if find/part line "INTERNAL" 8 [
                                                print "internal referral"
                                                mode: 'finish ;'
                                            ]
                                        ]

                                        'diagnosis [
                                            if any [find line "Page 2" find line "….2"] [
                                                print "switching to page-2-diagnoses"
                                                mode: 'page-2-diagnoses
                                            ]
                                            either find line "Medicat" [
                                                mode: 'medication ;'
                                                if not empty? diagnosis-detail [; catch end of list issue
                                                    append/only diagnoses reduce [trim/tail diagnosis-detail]
                                                    diagnosis-detail: copy ""
                                                ]
                                            ] [
                                                case [
                                                    parse? line [opt some whitespace "-" opt some whitespace copy dline to end | ; this is diagnosis detail
                                                        opt some whitespace some alpha "." opt some whitespace copy dline to end | ; so is this
                                                        opt some whitespace some alpha ":" opt some whitespace copy dline to end | ; so is this
                                                        opt some whitespace alpha ")" opt some whitespace copy dline to end ; a), b)^- ; so is this
                                                    ] [
                                                        if dline [
                                                            trim/head/tail dline
                                                            append diagnosis-detail join dline "; "
                                                        ]
                                                    ]
                                                    parse? line [
                                                        some digit "." opt some whitespace copy line to end | ; where the diagnosis starts with a digit
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
                                        'page-2-medications [
                                            print ["In mode: " mode]
                                            ; ?? line
                                            if find/part line "NHI:" 4 [
                                                mode: 'medication ;'
                                                oldmode: 'page-2-medications ;'
                                            ]
                                        ]

                                        'page-2-diagnoses [
                                            if find/part line "NHI:" 4 [
                                                mode: 'diagnoses ;'
                                                oldmode: 'page-2-diagnoses ;'
                                            ]
                                        ]

                                        'medication [
                                            ; medications can spill into the next page
                                            ?? line
                                            case [
                                                any [find line "Page 2" find line "….2"] [
                                                    print "switching to page-2-medications"
                                                    mode: 'page-2-medications ;'
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
                                                    print "added to medications"
                                                ]
                                            ]
                                        ]

                                        'dmards [
                                            either any [find line "DMARD" find line "Previous" find line "Medications"] [
                                            ] [
                                                append dmards line
                                            ]
                                        ]

                                        'finish [
                                            print "Finished processing or no diagnoses/medications in this letter 677"
                                            dump diagnoses
                                            dump medications
                                            break
                                        ]
                                    ]

                                ]
                            ]
                        ]
                        if debug [
                            ?? address
                            ?? areacode
                            ?? mobile
                            ?? phone
                            ?? email
                            ?? fp
                            ?? current-doc
                            ?? fpaddress
                            ?? medications
                            ?? diagnoses
                            ?? diagnosis-detail
                            ?? dmards
                        ]
                        ; ++ cnt
                        ; if cnt > 100 [halt]
                        ; now we have all the data, need to start adding
                        ; FP - record the ID
                        ; Medical Centre - record the ID
                        ; patient NHI - record the ID
                        ; patient details - record the ID
                        ; patient diagnoses
                        ; patient medications

                        ;; FP "Dr A J Greenway" "Dr C van Hutten" "Dr E Van der Merwe" Dr Van de Vyer "Dr D V Le Page" Ms J Harrington
                        if fp [
                            print "processing fp 729"
                            fpblock: split fp space
                            fpblockrev: reverse copy fpblock
                            fptitle: first fpblock
                            dump fpblock
                            dump fptitle
                            dump fpname
                            take/last fpblock
                            remove fpblock
                            fpinits: unspaced fpblock
                            dump fpinits
                            if null? fpinits [ ; no title so presumably a nurse practitoner
                                fpinits: copy fptitle
                                fptitle: copy ""
                            ]
                            if not all [fpname fptitle][
                                case/all [
                                    fpblockrev.2 = "Le" [remove/part skip fpblockrev 1 1 poke fpblockrev 1 rejoin ["Le " fpblockrev.1]]
                                    fpblockrev.2 = "van" [remove/part skip fpblockrev 1 1 poke fpblockrev 1 rejoin ["van " fpblockrev.1]]
                                    all [fpblockrev.3 = "van" any [fpblockrev.2 = "der" fpblockrev.2 = "de"]] [remove/part skip fpblockrev 1 2 poke fpblockrev 1 rejoin ["Van Der " fpblockrev.1]]
                                ]

                                fpblock: reverse copy fpblockrev
                                fpname: copy last fpblock
                                fptitle: copy first fpblock
                                parse fp [fptitle copy fpinits to fpname (trim/head/tail fpinits) to end]
                            ]
                            ; are they already in the database
                            replace/all fpname "'" "''"
                            if all [fpname <> "unknown" 4 > length-of fptitle ][ ; avoid Health Hub - no GP
                                sql-execute [
                                    SELECT id, fname, surname
                                    FROM fps
                                    WHERE surname = @fpname AND fname = @fpinits
                                ]
                                result: copy port
                                either not empty? result [
                                    fpid: result.1.1
                                ] [
                                    ; not there, so insert
                                    sql-execute [
                                        INSERT INTO fps (title, fname, surname)
                                        VALUES (@fptitle, @fpinits, @fpname)
                                    ]

                                    sql-execute [
                                        SELECT id, fname, surname
                                        FROM fps
                                        WHERE surname = @fpname AND fname = @fpinits
                                    ]

                                    result: copy port
                                    fpid: result.1.1
                                    print "Added FP"
                                ]
                            ]
                        ]
                        ; add or get medical centre
                        ; fpaddress
                        if not empty? fpaddress [
                            print "we have a fpaddress 819"
                            dump fpaddress
                            sql-execute [
                                SELECT id FROM gpcentre WHERE centrename = @fpaddress.1
                            ]

                            result: copy port
                            dump result
                            either not empty? result [
                                gpcentreid: result.1.1  ; or result.1 ?
                            ] [
                                print "Line 830"
                                dump fpaddress
                                if null? fpaddress.2 [append fpaddress copy ""]
                                if null? fpaddress.3 [append fpaddress copy ""]
                                dump fpaddress
                                print "Line 833"

                                sql-execute [
                                    INSERT INTO gpcentre (centrename, street, town)
                                    VALUES (@fpaddress.1, @fpaddress.2, @fpaddress.3)
                                ]

                                sql-execute [
                                    SELECT id
                                    FROM gpcentre
                                    WHERE centrename = @fpaddress.1
                                ]

                                result: copy port
                                print "dumping centreid at 781"
                                dump result
                                gpcentreid: result.1.1
                            ]
                        ] else [
                            print "No fpaddress 846"

                        ]

                        ; Get NHI
                        if any [not blank? nhi nhi] [
                            ; we have a parsed nhi
                            uppercase nhi ;  Note NHI here is alphanumeric
                            print "Going to see if we have the patient already"
                            dump nhi
                            dump letter-nhi
                            sql-execute [SELECT ID FROM NHILOOKUP WHERE nhi = @nhi]
                            if not empty? result: copy port [
                                dump result
                                nhiid: result.1.1
                            ] else [
                                sql-execute [INSERT INTO NHILOOKUP (NHI) values (@nhi)]
                                sql-execute [SELECT ID FROM NHILOOKUP WHERE nhi = @nhi]
                                result: copy port
                                dump result
                                nhiid: result.1.1
                            ]
                        ] else [; no NHI so need to abandon this letter
                            print "No NHI"
                            mode: 'abandon ;'
                        ]
                        if any [blank? surname blank? dob] [mode: 'abandon] ;' failed to parse this letter
                        if mode <> 'abandon [;'
                            ; nhiid, fpid, fpcentreid
                            ; surname, fname, [sname], areacode, email, mobile, phone, clinician, dob
                            ; address [line1 [line2] town]
                            ; so let us see if this person is in the database of patients
                            dump nhiid
                            sql-execute [SELECT id FROM patients WHERE nhi = @nhiid]
                            either not empty? result: copy port [
                                print "patient already in database..."
                            ] [
                                print "about to check patient details 818"
                                dump dob
                                dob: to date! dob
                                areacode: to integer! areacode
                                if 2 = length-of address [insert skip address 1 copy ""]
                                email: any [email copy ""]
                                phone: any [phone copy ""]
                                mobile: any [mobile copy ""]
                                sname: any [sname copy ""]
                                areacode: any [areacode "0000"]
                                ;for-each v reduce [nhiid current-doc dob address.1 address.2 address.3 areacode email phone mobile fpid gpcentreid][
                                ;    ?? V
                                ;]
                                dump fpid
                                dump sname
                                dump gpcentreid
                                sql-execute [
                                    INSERT INTO patients (
                                        nhi, clinicians,
                                        dob, surname, fname, sname,
                                        street, street2, town, areacode,
                                        email, phone, mobile,
                                        gp, gpcentre
                                    )
                                    VALUES (
                                        @nhiid, @current-doc,
                                        @dob, @surname, @fname, @sname,
                                        @address.1, @address.1, @address.3, @areacode,  ; !!! Should this use @address.2?
                                        @email, @phone, @mobile,
                                        @fpid, @gpcentreid
                                    )
                                ]
                            ]

                            ; now add the medications if this list is newer than an old list
                            sql-execute [
                                SELECT * FROM medications
                                WHERE nhi = @nhiid
                                ORDER BY letter DESC
                            ]
                            ; remove all the old medications?
                            if not empty? result: copy port [
                                ; we have old medications, so get the clinc date and see if it is older or newer
                                print "Getting last clinic date"
                                dump result
                                lastclinic: result.1.3
                                lastclinic: lastclinic.date
                                dump ldate
                                dump lastclinic
                                if all [ldate > lastclinic not empty? medications] [
                                    ; this letter is newer, we have a new medication list, so remove all old medications
                                    sql-execute [DELETE FROM medications WHERE nhi = @nhiid]
                                ]
                            ] else [lastclinic: 1-Jan-1900]
                            dump lastclinic
                            print "adding medications if there are none, or if this is a newer clinic letter"
                            if any [empty? result ldate > lastclinic] [
                                ; let us start adding medications by name and not code
                                if not empty? medications [
                                    print "Adding medications"
                                    for-each drug medications [
                                        dump drug
                                        if 128 < length-of drug [
                                            if find "-*" drug.1 [ ; is there a bullet in front?
                                                ; drug details
                                            ] else [
                                                ; must be now in the body of the letter
                                                ; can't assume if medications empty that in body as some letters don't have medications or vitals
                                                print "long sentence set finish 878"
                                                mode: 'finish
                                                break
                                            ]
                                        ]
                                        attempt [trim/tail drug]
                                        if parse? drug [not-drug-rule to end][
                                            ; not a drug, probably a comment, so skip to next drug
                                            print "Not a drug probably so lets continue"
                                            continue
                                        ]
                                        drugname: dosing: _
                                        parse drug [copy drugname drugname-rule copy dosing to end]
                                        if not blank? drugname [trim/tail drugname] else [continue]
                                        dump drugname
                                        dosing: any [dosing copy ""]
                                        if empty? dosing [
                                            ; try and just use the first name as the drugname and the rest as dosing
                                            parse copy drugname [copy drugname to space some space copy dosing to end]
                                        ]
                                        dump drugname dump dosing
                                        if not blank? drugname [
                                            sql-execute [
                                                SELECT * FROM medications
                                                WHERE nhi = @nhiid AND name = @drugname AND active = {'T'}
                                            ]
                                            result: copy port
                                            if not empty? result [
                                                dump medications
                                                print "Lets see what we have"
                                                for-each record medications [
                                                    probe record
                                                ]
                                                ;fail "Adding duplicate record" - typist has the same drug twice
                                                continue
                                            ]
                                            ; the odbc driver should truncate for us
                                            ;if not blank? dosing [
                                            ;    dosing: copy/part dosing 127
                                            ;]
                                            print "Inserting into medications 976"
                                            sql-execute [
                                                INSERT INTO medications (
                                                    nhi, letter, name, dosing, active
                                                ) VALUES (
                                                    @nhiid, @ldate, @drugname, @dosing, {'T'}
                                                )
                                            ]
                                        ] else [
                                            ; this is probably dosing for the last drug so consider adding in
                                        ]
                                    ]
                                ]
                                if not empty? dmards [
                                    print "Adding DMARDS"
                                    for-each drug dmards [
                                        dump drug
                                        parse drug [copy drugname drugname-rule copy dosing to end]
                                        dosing: any [dosing copy ""]
                                        dump drugname
                                        print form length-of drugname
                                        dump dosing
                                        print "Inserting into medications 1031"
                                        sql-execute [
                                            INSERT INTO medications (
                                                nhi, letter, name, dosing, active
                                            ) VALUES (
                                                @nhiid, @ldate, @drugname, @dosing, {'F'}
                                            )
                                        ]
                                    ]
                                ]
                            ]
                        ]

                        ; now add the diagnoses, removing any existing ones
                        ; == should we check to see if this letter is newer or older than latest?? ==
                        if not empty? diagnoses [
                            ; see how many diagnoses there are
                            sql-execute  [{select count(*) from diagnoses where nhi = } @nhiid]
                            result: copy port
                            if not empty? result [
                                result: result.1.1
                                if result <= length-of diagnoses [
                                    ;  existing diagnoses are fewer than we now have so lets delete existing
                                    sql-execute [DELETE FROM diagnoses WHERE nhi = @nhiid]
                                ]
                            ]
                            ; do we have to look at the case where new diagnoses are less than existing?
                            if odd? length-of diagnoses [append/only diagnoses [""]]
                            print "Adding diagnoses now 1024"
                            for-each [diagnosis detail] diagnoses [
                                dump diagnosis
                                dump detail
                                    sql-execute [
                                        INSERT INTO diagnoses (
                                            nhi, letter, diagnosis, detail
                                        ) VALUES (
                                            @nhiid, @ldate, @diagnosis, @detail.1
                                        )
                                    ]
                            ]
                        ]

                        ; finished the work, now update the letters table
                        dump ldate
                        ; replace/all contents "'" "''"
                        sql-execute [
                            INSERT INTO letters (
                                clinicians, nhi, cdate, dictation, checksum
                            ) VALUES (
                                @current-doc, @nhiid, @ldate, @contents, @ck
                            )
                        ]
                        print "Inserted into letters the file contents"
                        sql-execute [
                            UPDATE files SET done = TRUE where id = @fileid
                        ]
                        print "Updated done flag"
                        print "================================================="
                    ] else [
                        ; we have process this letter already
                        print "Letter already processed"
                    ]
                ]
            ] else [
                ; no doc found, skip this letter
                print "this clinician not found, skipping letter"
            ]
        ] else [
            print ["Letter of filename" join dir filename "doesn't meet pattern match required"]
        ]
    ] else [
        print ["Letter of filename" filename "missing from directory" dir]
        missing-files: me + 1
    ]
] ; end of processing all the records in files table

print unspaced ["Number of missing files:" form missing-files]
print unspaced ["Number of mismatched nhi:" form mismatch-nhi]

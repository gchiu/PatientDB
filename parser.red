Red [
	title: "letter parser"
]

parse-contents: func [source
	/local mode address fpaddress diagnosis-detail diagnoses dmards medications
	space whitespace digit areacode-rule dob-rule name-rule
	fname-rule uc nhi-rule filename-rule months phone-rule mobile-rule drugname-rule diagnosis-rule
	rfn oldmode longdate contents patient-o mobile phone email sname debug
] [
	debug: false
	; contents: read rfn: to-red-file filename: filename: "D:\2020\2020\November\CLU3365-HElasir-20201124-1.txt"
	; nhi: "CLU3365" ;"DLV5219" ; "GJS2525"

	;; variables
	address: copy []
	fpaddress: copy []
	diagnosis-detail: copy ""
	diagnoses: copy []
	dmards: copy []
	medications: copy []

	;; charsets and parse rules

	sname: mobile: phone: areacode: street: town: none

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

	oldmode: none

	patient-o: make object! [
		fname: sname: surname: dob: street: town: areacode: email: phone: mobile: clinicdate: none
		medications: copy []
		diagnoses: copy []
		dmards: copy []
		fp: make object! [
			inits: none
			name: none 
			street: none
			town: none
			centre: none
		]
	]



	; contents: read rfn: to-red-file filename: filename: "D:\2020\2020\November\CLU3365-HElasir-20201124-1.txt"
	; first line contains the date

	contents: split trim/head/tail copy consultation/text "^/"
	; get the long date out - do we really need to though?

	day-rule: charset [#"1" - #"3"] ; look for first digit in a day of the month
	non-day-rule: complement day-rule

	; quit the parser if can not find the date
	either parse contents/1 [ any alpha any space any alpha any space opt ":" any space
		copy day 1 2 digit space copy month some alpha space copy year 4 digit to end][
		longdate: rejoin [day " " month " " year]
		patient-o/clinicdate: load rejoin [day "-" copy/part month 3 "-" year]
	][
		; ?? firstline
		print "unable to parse date out"
		return false
	]

	;=======parser starts
	mode: 'date
	foreach line contents [; split into lines and parse each line
		trim/head/tail line
		if debug [
			?? line
			?? mode
		]
		either empty? line [
			case [

				all [mode = 'medication not empty? medications] [
					either oldmode = 'page-2-medications [

					] [
						; print "empty line, in medication mode, and not empty medications"
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
				mode: 'finish ;'
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
					; either parse/all line [uc some name-rule ", " copy fname fname-rule opt [" " copy sname to end] end] [
					either parse line [uc some name-rule ", " copy fname fname-rule opt [" " copy sname to end] end] [
						; we have surnames, and first names
						; parse/all line [copy surname to ","]
						parse line [copy surname to ","]
						; ?? surname ?? fname ?? sname
						surname: uppercase surname
						fname: uppercase fname
						if sname [sname: uppercase sname]
						patient-o/surname: surname
						patient-o/fname: fname
						patient-o/sname: sname
						mode: 'nhi ;'
					] [
						; print ["can't find name in line " line]
						mode: 'abandon ;' maybe try alternate name parser
					]
				]

				nhi [; confirm nhi matches that from the filename
					if parse line ["NHI: " copy letter-nhi nhi-rule] [
						;either letter-nhi <> nhi [
						;	print "Mismatch on file NHI and Letter NHI"
						;	break
						;] [
							mode: 'address ;'
						;]
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
							patient-o/dob: load dob
						]

						; parse/all line ["GP: " copy fp to end] [
						parse line ["GP: " copy fp to end] [
							fpname: last split fp space ; parse fp none
							patient-o/fp/name: fpname
							attempt [
								patient-o/fp/inits: copy/part fp find fp fpname
							]
							mode: 'fp ;' got the FP name
						]

						; parse/all line [some [phone-rule | mobile-rule | space] end] []
						parse line [some [phone-rule | mobile-rule | space] end] [
							patient-o/mobile: mobile
							patient-o/phone: phone
						]

						find line "@" [patient-o/email: copy line]

						true [; just address lines
							; get area code out
							rline: reverse copy line
							; if parse/all rline [copy areacode areacode-rule space copy line to end] [
							if parse rline [copy areacode areacode-rule space copy line to end] [
								areacode: reverse areacode
								line: reverse line
								patient-o/areacode: areacode
							]
							append/only address line
						]
					]
				]

				comment {
Dr A E Hughes	cc:	ENT Department, PNH 
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
						; print "internal referral"
						mode: 'finish ;'
					]
				]

				diagnosis [
					if any [find/part line "Page " 5 find/part line "…" 1] [
						; print "switching to page-2-diagnoses"
						mode: 'page-2-diagnoses ;'
					]
					either find/part line "Medicat" 7 [
						mode: 'medication ;'
						if not empty? diagnosis-detail [; catch end of list issue
							append/only diagnoses reduce [trim/tail diagnosis-detail]
							diagnosis-detail: copy ""
						]
					] [
						; check to see if leading number eg. 1. or -, the former to be removed and the latter indicates details
						; 1. 	Psoriatic Arthritis
						; 		a. CCP+ve
						;		b) RF-ve
						; Anti-CCP +ve rheumatoid arthritis 
						case [
							; parse/all line [any whitespace "-" any whitespace copy dline to end | ; this is diagnosis detail
							parse line [any whitespace "-" any whitespace copy dline to end | ; this is diagnosis detail
								any whitespace some alpha "." any whitespace copy dline to end | ; so is this
								any whitespace some alpha ":" any whitespace copy dline to end | ; so is this
								any whitespace alpha ")" any whitespace copy dline to end ; a), b)^- ; so is this
							] [
								if dline [
									trim/head/tail dline
									append diagnosis-detail join dline "; "
								]
							]
							; parse/all line [
							parse line [
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
					; print reform ["In mode: " mode]
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
						oldmode: 'page-2-diagnoses ;'
					]
				]

				medication [
					; medications can spill into the next page
					; ?? line
					case [
						any [find/part line "Page " 5 find/part line "…" 1] [
							; print "switching to page-2-medications"
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
						] [ ;print "**************Found DMARD line**************"
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
					; print "Finished processing or no diagnoses/medications in this letter"
					break
				]
			]

		]
	]
	if not empty? address [
		patient-o/street: address/1
		patient-o/town: address/2
	]
	if not empty? fpaddress [
		patient-o/fp/centre: fpaddress/1
		patient-o/fp/street: fpaddress/2
		patient-o/fp/town: fpaddress/3
	]
	;=============parser ends

	patient-o/medications: medications
	patient-o/dmards: dmards
	patient-o/diagnoses: diagnoses

	return patient-o
	; probe patient-o
]



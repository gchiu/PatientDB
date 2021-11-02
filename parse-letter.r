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
digit: charset [#"0" - #"9"]
areacode-rule: [4 digit]
dob-rule: [2 digit "." 2 digit "." 4 digit]
alpha: charset [#"a" - #"z" #"A" - #"Z"]
name-rule: charset [#"a" - #"z" #"A" - #"Z" #"-" #"'"]
uc: charset [#"A" - #"Z"]
nhi-rule: [3 alpha 4 digit]
filename-rule: [nhi-rule "-" some alpha "-202" 5 digit "-" digit ".txt"]
months: ["January" "February" "March" "April" "May" "June" "July" "August" "September" "October" "November" "December"]
phone-rule: [["P:" | "Ph:"] space copy phone some digit]
mobile-rule: ["M:" space copy mobile some digit]

cnt: 0

insert port [{select id, filename from files where done = (?)} false]
foreach record copy port [
	fileid: record/1
	filename: record/2
	?? filename
	nhi: uppercase copy/part filename 7
	current-doc: none
	if parse filename [NHI "-" copy clinician some alpha thru "-" copy ldate 8 digit "-" to ".TXT" to end] [
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
			ck: checksum/secure contents
			lines: deline/lines contents ; split into lines and parse each line
			surname: fname: sname: mobile: phone: dob: fp: email: areacode: fpname: none
			address: copy [] fpaddress: copy [] medications: copy [] diagnoses: copy [] dmards: copy []
			diagnosis-detail: copy ""
			mode: 'date ;'
			foreach line lines [
				trim/head/tail line
				either not empty? line [
					switch mode [
						date [
							if find line longdate [
								; now we are in the header
								mode: 'name ;'
							]
						]

						name [;look for patient name next eg. XXXX, XXXX XXXX 
							?? line
							either parse/all line [uc some name-rule ", " copy fname some name-rule opt [" " copy sname to end] end] [
								; we have surnames, and first names
								parse/all line [copy surname to ","]
								?? surname ?? fname ?? sname
								surname: uppercase surname
								fname: uppercase fname
								if sname [sname: uppercase sname]
								mode: 'nhi ;'
							] [
								print ["can't find name in line " line]
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

						address [; start capturing address lines and dob mixed in together, terminated by finding GP:
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
										append fpaddress line
									]
								]

							]
						]

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
							either find/part line "Medication" 10 [
								mode: 'medication ;'
							] [
								; check to see if leading number eg. 1. or -, the former to be removed and the latter indicates details
								?? line
								case [
									parse/all line [some digit "." any space copy line to end | copy line to end ] [
										submode: 'gotdx ;'
										append diagnoses line
									]
									parse/all line [any space "-" any space copy dline to end] [
										if line [
											append diagnosis-detail join dline newline
										]
									]
								]
								append diagnoses line
							]
						]

						medication [
							either find line "DMARDS" [
								mode: 'dmards ;'
							] [
								append medications line
							]
						]

						dmards [
							append dmards line
						]

						finish [
							print "break out of lines"
							break
						]
					]

				] [
					if mode = 'medication [mode: 'finish]
					if mode = 'dmards [mode: 'finish]
				]
			]
			?? mode
			?? longdate
			?? nhi
			?? surname
			?? fname
			?? sname
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
			++ cnt
			if cnt > 100 [halt]
			print "================================================="
		] [
			; no doc found, skip this letter
		]
	]
]

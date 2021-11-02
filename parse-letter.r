Rebol [

	notes: {parse the letters to extract name, nhi, drug information etc}
]

dbase: open odbc://patients
port: first dbase

; dir: %2021/2021/October/
dir: %test-parser/

; get all the clinicians first
insert port {select id, surname from clinicians}
clinicians: copy []
foreach c copy port [
	append clinicians reduce [c/2 c/1]
]
; Chiu 1 Elasir 2
probe clinicians

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
filename-rule: [nhi-rule "-" some alpha "-202" 5 digit "-" digit ".txt"]
months: ["January" "February" "March" "April" "May" "June" "July" "August" "September" "October" "November" "December"]
phone-rule: [["P:" | "Ph:"] space copy phone some digit]
mobile-rule: ["M:" space copy mobile some digit]

diagnosis-rule: complement charset [#"^-"]
; Anti-CCP +ve rheumatoid arthritis 
; Chickenpox pneumonia (age 31 years) with residual granulomata seen on chest x-ray 

cnt: 1 ; number of iterations in the current directory
checks: copy []
records: copy []

insert port [{select id, filename from files where done = (?)} false]
foreach record copy port [
	fileid: record/1
	filename: record/2
	if exists? to file! join dir filename [
		append/only records record
		print reform ["files:" ++ cnt]
		print reform ["Processing" filename]
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
				longdate: rejoin [to integer! day " " pick months to integer! month " " year]
				?? longdate

				surname: fname: sname: mobile: phone: dob: fp: email: areacode: fpname: none
				address: copy [] fpaddress: copy [] medications: copy [] diagnoses: copy [] dmards: copy []
				diagnosis-detail: copy ""

				; now read the letter to parse the contents
				contents: read join dir filename
				ck: form checksum/secure contents ; we have the checksum to prevent us from processing the same file twice
				either find checks ck [
					; should never happen as there is a unique constraint on the filename column
					print "checksum duplicate!"
					halt
				] [
					append checks ck
				]
				; now check to see if the letters database has this letter or not
				insert port [{select id from letters where checksum = (?)} ck]
				either none? pick port 1 [; okay not done yet
				mode: 'date ;' we look for the date first to start the processing
				foreach line deline/lines contents [; split into lines and parse each line
					trim/head/tail line
					either not empty? line [
						switch mode [
							date [
								if find line longdate [
									; now we are in the header
									mode: 'name ;'
								]
							]

							name [;look for patient name next eg. XXXX, XXXX XXXX or XXX XXX, XXX XXX
								?? line
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
									halt
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
								either find line "Medicat" [
									mode: 'medication ;'
								] [
									; check to see if leading number eg. 1. or -, the former to be removed and the latter indicates details
									; 1. 	Psoriatic Arthritis
									; Anti-CCP +ve rheumatoid arthritis 
									?? line
									case [
										parse/all line [any whitespace "-" any whitespace copy dline to end |
											any whitespace alpha ")" any whitespace copy dline to end ; a), b)^-
										] [
											if dline [
												trim/head/tail dline
												append diagnosis-detail join dline newline
											]
										]
										parse/all line [
											some digit "." any whitespace copy line to end | ; where the diagnosis starts with a digit
											copy line some diagnosis-rule to end
										] [
											; submode: 'gotdx ;'
											trim/head/tail line
											if not empty? diagnosis-detail [
												append/only diagnoses reduce [trim/tail diagnosis-detail]
												diagnosis-detail: copy ""
											]
											append diagnoses line
										]
									]
									; append diagnoses line
								]
							]

							medication [
								?? line
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
								print "break out of lines as no diagnosis or medications in this letter"
								break
							]
						]

					] [
						if all [mode = 'medication not empty? medications] [
							print "empty line, in medication mode, and not empty medications"
							mode: 'finish
						]
						if all [mode = 'dmards not empty? dmards] [mode: 'finish]
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
				; ++ cnt
				; if cnt > 100 [halt]
				print "================================================="
				][
					print "letter already in database"
				]
			] [
				; no doc found, skip this letter
			]
		]
	]
]

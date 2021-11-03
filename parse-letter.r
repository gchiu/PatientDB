Rebol [

	notes: {parse the letters to extract name, nhi, drug information etc}
]

dbase: open odbc://patients
port: first dbase

; dir: %2021/2021/October/
; dir: %test-parser/
dir: %2021/2021/September/

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
drugname-rule: [some [some alpha opt space]]

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
										?? line
										case [
											parse/all line [any whitespace "-" any whitespace copy dline to end | ; this is diagnosis detail
												any whitespace some alpha "." any whitespace copy dline to end | ; so is this
												any whitespace alpha ")" any whitespace copy dline to end ; a), b)^- ; so is this
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
												; now add the details as a block
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
					; now we have all the data, need to start adding 
					; FP - record the ID
					; Medical Centre - record the ID
					; patient NHI - record the ID
					; patient details - record the ID
					; patient diagnoses
					; patient medications

					;; FP "Dr A J Greenway" "Dr C van Hutten" "Dr E Van der Merwe" "Dr D V Le Page"
					if fp [
						fpblock: parse fp none
						fpblockrev: reverse copy fpblock
						case/all [
							fpblockrev/2 = "Le" [remove/part skip fpblockrev 1 1 poke fpblockrev 1 rejoin ["Le " fpblockrev/1]]
							fpblockrev/2 = "van" [remove/part skip fpblockrev 1 1 poke fpblockrev 1 rejoin ["van " fpblockrev/1]]
							all [fpblockrev/3 = "van" fpblockrev/2 = "der"] [remove/part skip fpblockrev 1 2 poke fpblockrev 1 rejoin ["Van Der " fpblockrev/1]]
						]
						fpblock: reverse copy fpblockrev
						fpsurname: copy last fpblock
						fptitle: copy first fpblock
						parse fp [fptitle copy fpinits to fpsurname (trim/head/tail fpinits) to end]
						; are they already in the database
						insert port [{select id, fname, surname from fps where surname =(?) and fname = (?)} fpsurname fpinits]
						result: pick port 1
						either result [
							fpid: result/1
						] [
							; not there, so insert
							insert port [{insert into fps (title, fname, surname) values (?, ?, ?)} fptitle fpinits fpsurname]
							insert port [{select id, fname, surname from fps where surname =(?) and fname = (?)} fpsurname fpinits]
							result: pick port 1
							fpid: result/1
							print "Added FP"
						]
					]
					; add or get medical centre
					; fpaddress
					if not empty? fpaddress [
						insert port [{select id from gpcentre where centrename = (?)} fpaddress/1]
						result: pick port 1
						either result [
							gpcentreid: result/1
						] [
							probe fpaddress
							if none? fpaddress/2 [append fpaddress copy ""]
							if none? fpaddress/3 [append fpaddress copy ""]
							insert port [{insert into gpcentre (centrename, street, town) values (?, ?, ?)} fpaddress/1 fpaddress/2 fpaddress/3]
							insert port [{select id from gpcentre where centrename = (?)} fpaddress/1]
							result: pick port 1
							?? result
							gpcentreid: result/1
						]
					]

					; Get NHI
					either any [not none? nhi nhi] [
						; we have a parsed nhi
						uppercase NHI
						insert port [{select id from NHILOOKUP where nhi=(?)} nhi]
						either result: pick port 1 [
							nhiid: result/1
						] [
							insert port [{insert into NHILOOKUP (NHI) values (?)} NhI]
							insert port [{select id from NHILOOKUP where nhi=(?)} nhi]
							result: pick port 1
							nhiid: result/1
						]
					] [; no NHI so need to abandon this letter
						print "No NHI"
						mode: 'abandon ;'

					]
					if any [none? surname none? dob][mode: 'abandon] ;' failed to parse this letter
					if mode <> 'abandon [ ;'
						; nhiid, fpid, fpcentreid
						; surname, fname, [sname], areacode, email, mobile, phone, clinician, dob 
						; address [line1 [line2] town]
						; so let us see if this person is in the database of patients
						insert port [{select id from patients where nhi = (?)} nhiid]
						either result: pick port 1 [
							print "patient already in database..."
						][
							print "about to check patient details"
							?? dob
							dob: to date! dob
							areacode: to integer! areacode
							if 2 = length? address [insert skip address 1 copy ""]
							email: any [email copy ""]
							phone: any [phone copy ""]
							mobile: any [mobile copy ""]
							sname: any [sname copy ""]
							;foreach v reduce [nhiid current-doc dob address/1 address/2 address/3 areacode email phone mobile fpid gpcentreid][
							;	?? V
							;]
							insert port [{insert into patients (nhi, clinicians, dob, surname, fname, sname, street, street2, town, areacode, email, phone, mobile, gp, gpcentre) values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)} nhiid current-doc dob surname fname sname address/1 address/2 address/3 areacode email phone mobile fpid gpcentreid]
						]
						; now add the medications
						; if there are medications, we will just skip rather than update
						insert port [{select * from medications where nhi=(?)} nhiid]
						if none? result: pick port 1 [
							print "adding medications"
							; let us start adding medications by name and not code
							if not empty? medications [
								foreach drug medications [
									?? drug
									parse drug [copy drugname drugname-rule copy dosing to end]
									dosing: any [dosing copy ""]
									?? drugname ?? dosing
									insert port [
										{insert into medications (nhi, name, dosing, active ) values (?, ?, ?, ?)} nhiid drugname dosing "T" 
									]
								]
							]
							if not empty? dmards [
								foreach drug dmards [
									?? drug
									parse drug [copy drugname drugname-rule copy dosing to end]
									dosing: any [dosing copy ""]
									?? drugname ?? dosing
									insert port [
										{insert into medications (nhi, name, dosing, active ) values (?, ?, ?, ?)} nhiid drugname dosing "F" 
									]
								]
							]
						]
					]

					print "================================================="
				] [
					print "letter already in database"
				]
			] [
				; no doc found, skip this letter
			]
		]
	]
]

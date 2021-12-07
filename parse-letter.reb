Rebol [
	author: "Graham Chiu"
	date: 4-Nov-2021
	notes: {parse the letters (file names stored in files database) to extract name, nhi, drug information, GP etc
		30.11.2021 since this uses `pick` we have to use rebol2 and not ren-c at present. Updated to update medications
        06.12.2021 start the port to renc
	}
]

if any [blank? system/script/args empty? system/script/args] [
    ; use this as the testing directory with no args
    dir: %2021/2021/October/
] else [
    dir: dirize to file! system/script/args
    if dir = %/ [
        fail "Can't use in current directory"
    ]
    if not exists? dir [
	    fail spaced ["dir" dir "does not exist"]
    ]
]

; get all sql and obdc needed
import %sql.reb

debug: false

; sql-execute

; get all the clinicians first
sql-execute {select id, surname from clinicians}
clinicians: copy []
for-each c copy port [
	append clinicians reduce [c/2 c/1]
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
drugname-rule: [some [some alpha opt space]]

diagnosis-rule: complement charset [#"^-"]
; Anti-CCP +ve rheumatoid arthritis 
; Chickenpox pneumonia (age 31 years) with residual granulomata seen on chest x-ray 

cnt: 1 ; number of iterations in the current directory
checks: copy []
records: copy []

; get all the filenames where the file has not yet been processed
cmd: {select id, filename from files where done IS FALSE}
print cmd
sql-execute cmd
; collect all the filenames
for-each record copy port [
	append/only records record
]

print spaced ["Number of files needed to process:" length-of records]

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
	fileid: record/1
    print spaced ["fileid" fileid]
	filename: record/2
    print spaced ["filename" filename]
	print spaced ["processing" filename]

	if exists? to file! join dir filename [
		; append/only records record
		print spaced ["files:" cnt: me + 1]
		print spaced ["Processing" filename]
		; nhi: uppercase copy/part filename 7
		current-doc: _
		; see if it matches the current filename format
        if parse? filename filename-rule [
            print spaced ["Filename passed rule" filename]
            nhi: letter-nhi: _
            parse filename [copy nhi nhi-rule "-" copy clinician some further alpha thru "-" copy ldate 8 digit "-" to ".txt" to end]
			; GChiu, Elasir
			if integer? current-doc: find-clinician clinician [
				; convert ldate to a proper date
                ?? ldate
				parse ldate [copy year 4 digit copy month 2 digit copy day 2 digit]
				ldate: to date! unspaced [day "-" month "-" year]
				print spaced ["clinician id is" current-doc]
				print spaced ["clinic letter date is" ldate]
				longdate: unspaced [to integer! day " " pick months to integer! month " " year]
				dump longdate

				surname: fname: sname: mobile: phone: dob: fp: email: areacode: fpname: _
				address: copy [] fpaddress: copy [] medications: copy [] diagnoses: copy [] dmards: copy []
				diagnosis-detail: copy ""

				; now read the letter to parse the contents
				contents: read join dir filename
                ck: form checksum 'md5 contents ; we have the checksum to prevent us from processing the same file content twice
				if find checks ck [
					; meaning that another file has the same contents as this one during this run
					print "checksum duplicate!"
					; halt
				] else [
					append checks ck ; and now start processing this letter
					; now check to see if the letters database has this letter or not
					; letters table holds files we have already processed
					sql-execute reword {select id from letters where checksum = '$checksum'} reduce ['checksum ck]
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

									mode = 'name []

									all [mode = 'dmards not empty? dmards] [mode: 'finish]
								]

							] else [; not an empty line	

								if find/part line "VITALS" 6 [
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
										if parse? line [uc some name-rule ", " copy fname fname-rule opt [" " copy sname to end] end] [
											; we have surnames, and first names
											parse line [copy surname to ","]
											dump surname dump fname dump sname
											surname: uppercase surname
											fname: uppercase fname
											if sname [sname: uppercase sname]
											mode: 'nhi
										] else [
											print unspaced ["can't find name in line " line]
											mode: 'abandon ;' maybe try alternate name parser
										]
									]

									'nhi [; confirm nhi matches that from the filename
										if parse? line ["NHI:" while further space copy letter-nhi nhi-rule] [
											either letter-nhi <> nhi [
												fail "Mismatch on file NHI and Letter NHI"
												break
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
											]

											parse? line ["GP: " copy fp to end] [
												fpname: last split fp space
												mode: 'fp ;' got the FP name
											]

											parse? line [some [phone-rule | mobile-rule | space] end] []

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
											; 1. 	Psoriatic Arthritis
											; 		a. CCP+ve
											;		b) RF-ve
											; Anti-CCP +ve rheumatoid arthritis 
											case [
												parse? line [while further whitespace "-" while further whitespace copy dline to end | ; this is diagnosis detail
													while further whitespace "•" while further whitespace copy dline to end | ; so is this
													while further whitespace some alpha "." while further whitespace copy dline to end | ; so is this
													while further whitespace some alpha ":" while further whitespace copy dline to end | ; so is this
													while further whitespace alpha ")" while further whitespace copy dline to end ; a), b)^- ; so is this
												] [
													if dline [
														trim/head/tail dline
														append diagnosis-detail join dline "; "
													]
												]
												parse? line [
													some digit "." while further whitespace copy line to end | ; where the diagnosis starts with a digit
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
										print spaced ["In mode: " mode]
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
										print "Finished processing or no diagnoses/medications in this letter"
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

										all [mode = 'dmards not empty? dmards] [mode: 'finish]
									]

								] [; not an empty line	

									if find/part line "VITALS" 6 [
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
													parse? line [while further whitespace "-" while further whitespace copy dline to end | ; this is diagnosis detail
														while further whitespace some alpha "." while further whitespace copy dline to end | ; so is this
														while further whitespace some alpha ":" while further whitespace copy dline to end | ; so is this
														while further whitespace alpha ")" while further whitespace copy dline to end ; a), b)^- ; so is this
													] [
														if dline [
															trim/head/tail dline
															append diagnosis-detail join dline "; "
														]
													]
													parse? line [
														some digit "." while further whitespace copy line to end | ; where the diagnosis starts with a digit
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
											print spaced ["In mode: " mode]
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
											print "Finished processing or no diagnoses/medications in this letter"
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

						;; FP "Dr A J Greenway" "Dr C van Hutten" "Dr E Van der Merwe" "Dr D V Le Page"
						if fp [
							fpblock: split fp space
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
							sql-execute reword {select id, fname, surname from fps where surname ='$surname' and fname = '$fname'} reduce ['surname fpsurname 'fname fpinits]
							result: copy port
							either not empty? result [
								fpid: result/1/1
							] [
								; not there, so insert
								sql-execute reword {insert into fps (title, fname, surname) values ('$title', '$fname', '$surname')} reduce ['title fptitle 'fname fpinits 'surname fpsurname]
								sql-execute reword {select id, fname, surname from fps where surname ='$surname' and fname = '$fname'} reduce ['surname fpsurname 'fname fpinits]
								result: copy port
								fpid: result/1/1
								print "Added FP"
							]
						]
						; add or get medical centre
						; fpaddress
						if not empty? fpaddress [
							sql-execute reword {select id from gpcentre where centrename = '$centre'} reduce ['centre fpaddress/1]
							result: copy port
							either not empty? result [
								gpcentreid: result/1/1 ; or result/1 ?
							] [
								probe fpaddress
								if blank? fpaddress/2 [append fpaddress copy ""]
								if blank? fpaddress/3 [append fpaddress copy ""]
								sql-execute reword {insert into gpcentre (centrename, street, town) values ('$centrename', '$street', '$town')} reduce ['centrename fpaddress/1 'street fpaddress/2 'town fpaddress/3]
								sql-execute reword {select id from gpcentre where centrename = '$centrename'} reduce ['centrename fpaddress/1]
								result: copy port
								?? result
								gpcentreid: result/1/1
							]
						]

						; Get NHI
						if any [not blank? nhi nhi] [
							; we have a parsed nhi
							uppercase nhi ;  Note NHI here is alphanumeric
                            print "Going to see if we have the patient already"
                            dump nhi
                            dump letter-nhi
							sql-execute replace copy {select id from NHILOOKUP where nhi = '?'} "?" nhi
							if not empty? result: copy port [
                                dump result
								nhiid: result/1/1
							] else [
								sql-execute replace copy {insert into NHILOOKUP (NHI) values ('?')} "?" nhi
								sql-execute replace copy {select id from NHILOOKUP where nhi= '?'} "?" nhi
								result: copy port
                                dump result
								nhiid: result/1/1
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
							sql-execute replace copy {select id from patients where nhi = ?} "?" nhiid
							either not empty? result: copy port [
								print "patient already in database..."
							] [
								print "about to check patient details"
								dump dob
								dob: to date! dob
								areacode: to integer! areacode
								if 2 = length-of address [insert skip address 1 copy ""]
								email: any [email copy ""]
								phone: any [phone copy ""]
								mobile: any [mobile copy ""]
								sname: any [sname copy ""]
								;for-each v reduce [nhiid current-doc dob address/1 address/2 address/3 areacode email phone mobile fpid gpcentreid][
								;	?? V
								;]
                                dump fpid
                                dump gpcentreid
                                dump sname
								sql-execute reword {insert into patients (nhi, clinicians, dob, surname, fname, sname, street, street2, town, areacode, email, phone, mobile, gp, gpcentre) values ($nhi, $clinicians, '$dob', '$surname', '$fname', '$surname', '$street', '$street2', '$town', $areacode, '$email', '$phone', '$mobile', $gp, $cid)} reduce ['nhi nhiid 'clinicians current-doc 'dob dob 'surname surname 'fname fname 'sname sname 'street address/1 'street2 address/2 'town address/3 'areacode areacode 'email email 'phone phone 'mobile mobile 'gp fpid 'cid gpcentreid]
							]
							; now add the medications if this list is newer than an old list
							sql-execute replace copy {select * from medications where nhi=? order by letter DESC} "?" nhiid
							; remove all the old medications?
							if not empty? result: copy port [
								; we have old medications, so get the clinc date and see if it is older or newer
                                print "Getting last clinic date"
                                dump result
								lastclinic: result/1/3
                                lastclinic: lastclinic/date
                                dump ldate
                                dump lastclinic
								if all [ldate > lastclinic not empty? medications] [
									; this letter is newer, we have a new medication list, so remove all old medications
									sql-execute replace copy {delete from medications where nhi = ?} "?" nhiid
								]
							] else [lastclinic: 1-Jan-1900]
                            dump lastclinic
							print "adding medications if there are none, or if this is a newer clinic letter"
							if any [blank? result ldate > lastclinic] [
								; let us start adding medications by name and not code
								if not empty? medications [
                                    print "Adding medications"
									for-each drug medications [
										?? drug
										parse drug [copy drugname drugname-rule copy dosing to end]
										dosing: any [dosing copy ""]
										dump drugname dump dosing
										sql-execute reword
										{insert into medications (nhi, letter, name, dosing, active ) values ($nhi, '$letter', '$name', '$dosing', 'T')} reduce ['nhi nhiid 'letter ldate 'name drugname 'dosing dosing]
									]
								]
								if not empty? dmards [
                                    print "Adding DMARDS"
									for-each drug dmards [
										?? drug
										parse drug [copy drugname drugname-rule copy dosing to end]
										dosing: any [dosing copy ""]
										?? drugname ?? dosing
										sql-execute reword
										{insert into medications (nhi, letter, name, dosing, active ) values ($nhi, '$letter', '$name', '$dosing', 'F')} reduce ['nhi nhiid 'letter ldate 'name drugname 'dosing dosing]
									]
								]
							]
						]

						; now add the diagnoses, removing any existing ones
						; == should we check to see if this letter is newer or older than latest?? ==
						if not empty? diagnoses [
							; see how many diagnoses there are
							sql-execute replace copy {select count(*) from diagnoses where nhi = ?} "?" nhiid
							result: copy port
							if not empty? result [
								result: result/1/1
								if result <= length-of diagnoses [
									;  existing diagnoses are fewer than we now have so lets delete existing
									sql-execute replace copy {delete from diagnoses where nhi = ?} "?" nhiid
								]
							]
							; do we have to look at the case where new diagnoses are less than existing?
							if odd? length-of diagnoses [append/only diagnoses [""]]
							for-each [diagnosis detail] diagnoses [
								sql-execute reword {insert into diagnoses (nhi, letter, diagnosis, detail) values ($nhi, '$letter', '$diagnosis', '$detail')} reduce ['nhi nhiid 'letter ldate 'diagnosis diagnosis 'detail detail/1]
							]
						]

						; finished the work, now update the letters table
                        dump ldate
						sql-execute reword {insert into letters (clinicians, nhi, cdate, dictation, checksum) values ($clinicians, $nhi, '$cdate', '$dictation', '$checksum')} reduce ['clinicians current-doc 'nhi nhiid 'cdate ldate 'dictation contents 'checksum ck]
                        print "Inserted into letters the file contents"
						sql-execute reword {update files set done = TRUE where id = $id} reduce ['id fileid]
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
			print spaced ["Letter of filename" join dir filename "doesn't meet pattern match required"]
		]
	] else [
		print spaced ["Letter of filename" filename "missing from directory" dir]
	]
] ; end of processing all the records in files table
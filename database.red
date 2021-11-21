Red [
	Needs 'view
	File: %database.red
	Author: "Graham Chiu"
	Date: 11-Nov-2021
	Title: "MidCentral Rheumatology Patient Database"
]

spreadsheet: "C:\Program Files\LibreOffice\program\scalc.exe "
jaks: ["Tofacitinib" "Rinvoq" "Upadacinitib"]
tnfs: ["Infliximab" "Remicade" "Humira" "Adalimumab" "Etanercept" "Enbrel"]
cyto: ["Cyclophosphamide" "Mycophenolate" "Prednisone"]
dmards: ["Azathioprine" "6-Mercaptopurine" "Methotrexate" "Leflunomide" "Arava" "Salazopyrin" "Sulfasalazine" "Hydroxychloroquine" "Plaquenil"]
infus: ["Rituximab" "Actemra" "Tocilizumab"]
inters: ["Cosentyx" "Secukinumab" "Stelara" "Ustekinumab"]
combos: ["Methotrexate+Leflunomide" "Methotrexate+Prednisone" "Leflunomide+Prednisone"]

history: copy []
if exists? %history.red [
	history: do %history.red
]

do %munge3.r
do %parser.red

sql-data: []
current-query: copy ""

get-clinician: func [id] [
	clinicians: [[1 "Chiu" "Graham" 1 none] [2 "Elasir" "Haitham" 1 none] [3 "Porten" "Lauren" 2 none] [4 "Sawyers" "Stephen" 1 none] [5 "Hawke" "Sonia" 2 none]]
	foreach c clinicians [
		if c/1 = id [
			return c/2
		]
	]
	return id
]

webroot: http://localhost:8888/

show-demogs: func [val
	/local d dob
	"show or hide personal data"
][
	agefld/visible?: dobfld/visible?:
	fnamefld/visible?: 
	surnamefld/visible?: val
	if none? surnamefld/text [exit]
	dob: d: none
	attempt [
		dob: to date! dobfld/data
		d: rejoin [ next form 100 + dob/day "." next form 100 + dob/month "." dob/year]
	]
	either val [
		if d [replace/all consultation/text "*DOB*" d]
		if patient-o/phone [
			replace/all consultation/text "*phone*" patient-o/phone 
		]
		if patient-o/mobile [
			replace/all consultation/text "*mobile*" patient-o/mobile
		]
		if patient-o/street [
			replace/all consultation/text "*street*" patient-o/street
		]
		replace/all consultation/text "*SURNAME*" surnamefld/text
		replace/all consultation/text "*FIRSTNAME*" fnamefld/text
	][
		if d [replace/all consultation/text d "*DOB*"]
		if patient-o/phone [
			replace/all consultation/text patient-o/phone "*phone*"
		]
		if patient-o/mobile [
			replace/all consultation/text patient-o/mobile "*mobile*"
		]
		if patient-o/street [
			replace/all consultation/text patient-o/street "*street*"
		]
		replace/all consultation/text surnamefld/text "*SURNAME*" 
		replace/all consultation/text fnamefld/text "*FIRSTNAME*"
	]
	exit
]

lay: layout [
	title "MidCentral Rheumatology Patient Database"
	style label: text bold
	tab-panel 1200x800 [
		"Patients" [
			panel [
				panel [
					panel [
						label "First Name" 70 fnamefld: field
						label "Surname" 50 surnamefld: field 110
						label "DOB" 30 dobfld: field 80
						label "Age" 30 agefld: field 25
						label "DBID" 30 dbidfld: field 40
						label "NHI" 30 nhifld: field "DLV5219" 60 on-enter [
							if not empty? face/text [get-patient face/text]
						]
						button "Find" [
							if not empty? nhifld/text [get-patient nhifld/text]
							; clear consultation/text
							; show-consult 1
						]
						button "Quit" font [color: red] [unview/all halt]
						return
						label "Clinic" 40 clinicfld: field 80
						label "Clinician" 50 clinfld: field 80
						label "FP" 30 gpfld: field 150
						label "Centre" 50 gpcentfld: field 200
						button "Parse" 45 green [
							if not none? consultation/text [
								p-obj: mold parse-contents consultation/text
								view parselo: layout [ 
									title "Parsed Letter" 
									below
									area 1000x600 wrap p-obj
									button "Close" [unview/only parselo]
									; button "See" [probe p-obj]
								]
							]
						]
						button "Clear" 45 [
							clear-fields
							dbidfld/text: copy ""
							nhifld/text: copy ""
							gpfld/text: copy ""
							agefld/text: copy ""
						]
						hideck: check "?" 10 true [show-demogs face/data]
					] return
					panel [
						clindates: text-list 80x600 [
							; show-consult pick face/data face/selected
							; probe face/selected
							show-consult face/selected
							show-demogs hideck/data
						]
						consultation: area 800x600 white wrap font [name: "Consolas" size: 10 color: black]
					]
				]
			]
			panel [
				label "Diagnoses" return
				dxtl: text-list 200x200 return
				label "Medications" return
				rxtl: text-list 200x260 return
				label "DMARD Hx" return
				dmtl: text-list 200x120
			]
		]
		"History" [
			panel 240x700 [
				across
				text bold "Patients" patientck: check false 10 [
					patientbox/visible?: not face/data
				]
				return
				pattl: text-list 200x650 data history [
					p: pick history face/selected
					nhi: copy/part p find p " "
					nhifld/text: copy nhi
					show nhifld
					get-patient nhi
					clear consultation/text
					show-consult 1
					show-demogs hideck/data
				]
				at 85x50 patientbox: box 100x650 gray 
			]
		]
		"Medication Queries" [
			panel 130x115 [
				below
				text bold "JAK inhibitors"
				jakfld: text-list 90x60 data jaks [
					display-data face
				]
			]

			panel 130x160 [
				below
				text bold "TNF inhibitors"
				tnffld: text-list 90x100 data tnfs [
					display-data face
				]
			]

			panel 150x120 [
				below
				text bold "Cytotoxics/Other"
				cytofld: text-list 120x65 data cyto [
					display-data face
				]
			]

			panel 150x210 [
				below
				text bold "DMARDS"
				dmardfld: text-list 120x150 data dmards [
					display-data face
				]
			]

			panel 150x110 [
				below
				text bold "Infusions"
				infusfld: text-list 120x60 data infus [
					display-data face
				]
			]
			panel 150x150 [
				below
				text bold "Interleukins"
				intersfld: text-list 120x90 data inters [
					display-data face
				]
			]
			panel 180x120 [
				below
				text bold "Combinations"
				combsfld: text-list 160x60 data combos [
					display-data face
				]
			]
			panel 80x120 [
				below
				button "Quit" font [color: red] [quit]
				button "Hide" [
					hidebox/visible?: true
				]
				button "Show" [
					hidebox/visible?: false
				]
			]
			return
			panel 1200x500 [
				below
				queryfld: area 1150x450 no-wrap
				at 50x30 hidebox: box 600x430 gray
				panel 1200x60 [
					across
					button "LibreOffice" font [color: red] [
						; data: copy ["SQL Query"]
						data: copy reduce [current-query]
						; probe data
						; insert/only sql-data copy ["NHI" "Surname" "FirstName" "Clinc" "Drug" "Notes" "Phone" "Mobile" "Street" "Town" "FP" "GP Centre"]
						append/only data sql-data
						append/only data []
						; probe data
						name: form checksum form sql-data 'md5
						remove/part name 2
						remove back tail name
						append name %.xlsx
						name: to file! name
						either exists? name [
							; alert rejoin [form name " exists already"]
						] [
							ctx-munge/write-excel name data
							; alert rejoin [form name " is now ready!"]
						]
						call rejoin [spreadsheet " " name]
						;]
						;alert "check file.xlsx"		
					]
					text bold "Query:" 40 qfld: text 200 text bold "Numbers:" 60 cntfld: text 100
				]
			]
		]
	]
	do [hidebox/visible?: false]
]

clear-fields: has [fields] [
	texts: reduce [consultation surnamefld fnamefld dobfld dbidfld gpcentfld clinfld clinicfld]
	foreach field texts [
		set in field 'text copy "" 
	]

	lists: reduce [clindates dxtl rxtl dmtl]
	foreach list lists [
		set in list 'data copy []
	]

	show consultation
	show surnamefld
	show consultation
	show clinfld
	show clinicfld
]



get-patient: func [nhi] [
	; /local patient-o
	; script: rejoin ["r3w.exe fetch-record.reb " nhifld/text]
	; script: rejoin ["r3.exe fetch-record.reb " {"} nhifld/text {"}]
	script: rejoin ["view.exe fetch-record.r " {"} nhifld/text {"}]
	; consultation/text: copy script
	; show consultation
	attempt [delete %patient.red]
	clear-fields
	call/wait script
	either exists? %patient.red [
		; consultation/text: read %patient.red
		; probe consultation/text
		do %patient.red
		surnamefld/text: patient-o/surname
		fnamefld/text: patient-o/fname
		dobfld/text: form patient-o/dob
		gpfld/text: patient-o/gpname
		gpcentfld/text: patient-o/gpcentname
		dbidfld/text: form patient-o/dbid
		age: now/date - patient-o/dob
		age: age / 365.25
		agefld/text: form to integer! age
		rxtl/data: patient-o/medications
		dxtl/data: patient-o/diagnoses
		dmtl/data: patient-o/dmards
		clindates/data: patient-o/dates
		; save this patient
		rec: rejoin [nhi " " patient-o/surname ", " patient-o/fname]
		if not find history rec [
			append history rec
			sort history
			history-string: copy ""
			foreach name history [
				append history-string rejoin [{"} name {" }]
			]
			if exists? %history.red [
				if exists? %history.old [delete %history.old]
				rename %history.red %history.old
			]
			write %history.red rejoin ["Red []^/^/history: [" history-string "]"]
		]
		if not empty? clindates/data [
			show-consult 1
		]
	] [
		clear-fields
		consultation/text: copy "Patient not found"
	]
]


; dates: ["30-Oct-2021" "27-Sep-2021" "25-Sep-2021" "7-Aug-2021" "26-Jun-2021" "26-Jun-2021" "3-May-2021" "8-Sep-2020" "6-Jul-2020" "12-May-2020" "1-Apr-2020" "5-Dec-2019" "14-Oct-2019" "21-May-2019" "15-May-2019"]

show-consult: func [id] [
	rec: pick patient-o/consults id
	consultation/text: copy rec/4
	clinfld/text: form get-clinician to integer! rec/3
	clinicfld/text: form rec/2
]

display-data: func [face
	/local res
] [
	either -1 = face/selected [
		queryfld/text: "Click again!"
	] [
		qfld/text: copy pick face/data face/selected
		queryfld/text: copy "working..."
		cntfld/text: copy "counting..."
		show qfld
		show queryfld
		current-query: copy pick face/data face/selected
		res: read rejoin [webroot "drug/" pick face/data face/selected "/"]
		res: load res
		sql-data: copy res
		queryfld/text: copy ""
		cntfld/text: form -1 + length? res
		foreach record res [
			append queryfld/text form record
			append queryfld/text newline
		]
	]
]

view lay
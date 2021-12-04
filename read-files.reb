Rebol [
	file: %read-files.reb
	notes: {
        reads all the files in dir that match the pattern in the filename-rule
        and stores them into the files table. By default, the `done` flag in the files table is false.
        So, this tells us which files we need to process for parsing later on.

        do/args %read-files.reb %2021/2021/October/

        5.12.2021 moved to ren-c and dir is now passsed as an arg
    }
]

dir: system/script/args

if not exists? dir [
    fail spaced ["dir" dir "does not exist"]
]

; get all sql and obdc needed
import %sql.reb

comment [
	is?: func [word] [
		null? any ['~attached~ = binding of word, unset? word]
	]

	isn't?: func [word] [not is? word]

	; read all the files into the files database
	if isn't? 'dir [
		print "Need to set dir, the directory to process"
		halt
	]
]

digit: charset [#"0" - #"9"]
alpha: charset [#"a" - #"z" #"A" - #"Z"]
nhi-rule: [3 alpha 4 digit]
filename-rule: [nhi-rule "-" some alpha "-20" 6 digit "-" digit ".txt"] ; only do from year 2000 onwards

for-each file read dir [
	; if the filename matches the filename-rule, then check to see if it is in the database
	; if not, then add it
	ffile: form file
	if parse? ffile filename-rule [
        print spaced ["Checking" ffile]
		sql-execute unspaced [{select * from files where filename ='} ffile "'"]
		if empty? copy port [
            print spaced ["Adding" ffile]
			sql-execute unspaced [{insert into files (filename) values ('} ffile {')}]
		]
	] else [
        print spaced [file "doesn't match pattern"]
    ]
]

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
    if did parse3 ffile filename-rule [
        print ["Checking" ffile]
        if e: error? sys.util.rescue [
            sql-execute [SELECT * FROM files WHERE filename = @ffile]
        ][
            print ":::::::::::::: sql error:::::::::::::::::"
            probe e
            continue
        ]
        if empty? copy port [
            print ["Adding" ffile]
            dump ffile
            if e: error? sys.util.rescue [
                sql-execute [
                    INSERT INTO files (filename) VALUES (@ffile)
                ]
                print ["Added" ffile]
            ][
                print ":::::::::::::: sql error:::::::::::::::::"
                cmd: [INSERT INTO files (filename) values (@ffile)]
                print ["try" mold cmd]
                sql-execute cmd
            ]
        ]
    ] else [
        print [file "doesn't match pattern"]
    ]
]

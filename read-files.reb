Rebol [
    file: %read-files.reb
    notes: --[
        reads all the files in dir that match the pattern in the filename-rule
        and stores them into the files table. By default, the `done` flag in
        the files table is false.

        So, this tells us which files we need to process for parsing later on.

        do:args %read-files.reb %2021/2021/October/

        5.12.2021 moved to ren-c and dir is now passsed as an arg
    ]--
]

; use this as the testing directory with no args
dir: %2021/2021/October/

if not any [null? system.script.args empty? system.script.args] [
    dir: dirize to file! system.script.args
    if dir = %/ [
        panic "Can't use in current directory"
    ]
    if not exists? dir [
        panic spaced ["dir" dir "does not exist"]
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
nhi-rule: [repeat 3 alpha repeat 4 digit]

; only do from year 2000 onwards
filename-rule: [nhi-rule "-" some alpha "-20" repeat 6 digit "-" digit ".txt"]

for-each 'file read dir [
    ;
    ; if the filename matches the filename-rule, then check to see if it is
    ; in the database.  if not, then add it.

    let ffile: form file
    parse3 ffile filename-rule except [
        print [file "doesn't match pattern"]
        continue
    ]

    print ["Checking" ffile]

    sys.util/recover [
        sql-execute [SELECT * FROM files WHERE filename = $ffile]
    ] then e -> [
        print ":::::::::::::: sql error:::::::::::::::::"
        probe e
        continue
    ]

    if empty? copy port [
        print ["Adding" ffile]
        dump ffile
        sys.util/recover [
            sql-execute [
                INSERT INTO files (filename) VALUES ($ffile)
            ]
            print ["Added" ffile]
        ] then e -> [
            print ":::::::::::::: sql error:::::::::::::::::"
            cmd: [INSERT INTO files (filename) values ($ffile)]
            print ["try" mold cmd]
            sql-execute cmd
        ]
    ]
]

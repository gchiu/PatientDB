Rebol []

do %../clean-script.r

clean: func [file [file!]
    /local content
][
    content: read file
    print length? content
    if 30 > length? content [
        print "file too short"
        halt
    ]
    write file clean-script content
    print "done"
]
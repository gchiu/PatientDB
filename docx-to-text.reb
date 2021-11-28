#!/usr/bin/r3
#
Rebol [
  example: "r3 path/to/docx-to-text document.docx"
  notes: {will write the text file with the same filename but .txt extension}
]

import 'markup ; maybe change to your location

load-docx: function [
  docx [file!]
] [
  t: make block! 24
  unzip/quiet t docx
  ; xml is defined in %markup.reb
  xml/load select t %"word/document.xml"
]
; ^-- look at result to understand format
; example:
comment [
  xml/load unspaced [
    <!xml>
    <p style="color: red">
    <br class="dummy" />
    "Lorem ipsum"
    </p>
    <!-- comment -->
  ] = [
    ; processing instruction:
    proc "xml"
    ; opening tag:
    ;    [<tagname> #attr "value"]
    otag [<p> #style "color: red"]
    ; void tag:
    ;    [<tagname> #attr "value"]
    vtag [<br> #class "dummy"]
    ; text
    text "Lorem ipsum"
    ; closing tag:
    ;    <tagname>
    ctag <p>
    ; comment
    comm " comment "
  ]
]

t: f: to-file system/script/args/1
t: load-docx t
d: copy ""

; extract text
for-each [k v] t [
  if k = 'text [write-stdout v
    append d deline v  ;== remove CRLF pairs and replace with LF
  ]
  if all [k = 'vtag, block? v, v/1 = <w:tab>][
    write-stdout "^-"
    append d "^-"
  ]
  if all [k = 'ctag, v = <w:p>] [
    print ""
    append d "^/"
  ]
]

replace f %.docx %.txt

f: open/new f
write/append f d
close f

; vim: set syn=rebol et sw=2:

#!/usr/bin/r3
REBOL [Name: webserver]
-help: does [lib/print {
USAGE: r3 webserver.reb [OPTIONS]
OPTIONS:
  -h, -help, --help : this help
  -q      : verbose: 0 (quiet)
  -v      : verbose: 2 (debug)
  INTEGER : port number [8000]
  OTHER   : web root [system/options/path]
  -a name : access-dir via name.*
EXAMPLE: 8080 /my/web/root -q -a index
}]

;; INIT
port: 8888
root-dir: %"./"
access-dir: false
verbose: 1

uparse system.options.args [while [
  "-a", access-dir: [
      <end> (true)
    | "true" (true)
    | "false" (false)
    | to-file/ <any>
  ]
  |
  ["-h" | "-help" | "--help" || (-help, quit)]
  |
  verbose: ["-q" (0) | "-v" (2)]
  |
  bad: into text! ["-" across to <end>] (
    fail ["Unknown command line switch:" bad]
  )
  |
  port: into text! [integer!]
  | 
  root-dir: to-file/ <any>
]]

;; LIBS

delete-recur: adapt :lib/delete [
  if file? port [
    if not exists? port [return null]
    if 'dir = exists? port [
      port: dirize port
      for-each x read port [
          delete-recur %% (port)/(x)
      ]
    ]
  ]
]

import %httpd.reb
attempt [
  rem: import 'rem
  html: import 'html
]
rem-to-html: attempt[chain [:rem/load-rem :html/to-html]]

change-dir system/options/path

ext-map: [
  "css" css
  "gif" gif
  "htm" html
  "html" html
  "jpg" jpeg
  "jpeg" jpeg
  "js" js
  "json" json
  "png" png
  "r" rebol
  "r3" rebol
  "reb" rebol
  "rem" rem
  "svg" svg
  "txt" text
  "wasm" wasm
]

mime: make map! [
  css "text/css"
  gif "image/gif"
  html "text/html"
  jpeg "image/jpeg"
  js "application/javascript"
  json "application/json"
  png "image/png"
  r "text/plain"
  svg "image/svg+xml"
  text "text/plain"
  wasm "application/wasm"
]

status-codes: [
  200 "OK" 201 "Created" 204 "No Content"
  301 "Moved Permanently" 302 "Moved temporarily" 303 "See Other" 307 "Temporary Redirect"
  400 "Bad Request" 401 "No Authorization" 403 "Forbidden" 404 "Not Found" 411 "Length Required"
  500 "Internal Server Error" 503 "Service Unavailable"
]

html-list-dir: function [
  "Output dir contents in HTML."
  dir [file!]
  ][
  if trap [list: read dir] [return _]
  ;;for-next list [if 'dir = exists? join dir list/1 [append list/1 %/]]
  ;; ^-- workaround for #838
  sort/compare list func [x y] [
    case [
      all [dir? x not dir? y] [true]
      all [not dir? x dir? y] [false]
      y > x [true]
      true [false]
    ]
  ]
  if dir != %/ [insert list %../]
  data: copy {<head>
    <meta name="viewport" content="initial-scale=1.0" />
    <style> a {text-decoration: none}
    body {font-family: monospace}
    .b {font-weight: bold}
    </style>
  </head>
  [>]: Navigate [V]: View [E]: Exec <hr/>
  }
  for-each i list [
    is-rebol-file: did all [
      not dir? i
      parse? i [thru ".reb"]
    ]
    append data unspaced [
      {<a }
      if dir? i [{class="b" }]
      {href="} i
      {?">[}
      case [
        is-rebol-file [{E}]
        dir? i [{>}]
      ] else [{V}]
      {]</a> }
      {<a }
      if dir? i [{class="b" }]
      {href="} i
      {">}
      i
      </a> <br/>
    ]
  ]
  data
]

parse-query: function [query] [

;  lib/print spaced ["parsing query: " query]

  xchar: charset "=&"
  r: make block! 0
  k: v: _
  query: to-text query
  i: 0
  parse query [any [
    copy k [to xchar | to end]
    [ "=" copy v [to "&" | to end]
    | (v: k k: i: i + 1)
    ]
    (
      append r (attempt [dehex k] else [k])
      append r (attempt [dehex v] else [v])
    )
    opt skip
  ]]
  r
]

request: _

handle-request: function [
    req [object!]
  ][

  probe req/request-uri

  ;==============handle get requests============================;
  case [
    ; drug names and combinations
    parse? req/request-uri ["/drug/" copy drugname to "/" to end][
      ; res: spaced ["drug request for users of" drugname]
      res: if find drugname "+" [
        fetch-combo-users drugname
      ] else [
        fetch-drug-users drugname
      ]
      return reduce [200 mime/html res]
    ]
    ; patient demographics
    parse? req/request-uri ["/patients/nhi/" copy nhi to "/" to end][
      if parse? nhi [3 alpha 4 digit][
        uppercase nhi
        sql-execute [{select id from NHILOOKUP where nhi =} ^nhi]
        if empty? result: copy port [
            nhi: "Not found"
        ] else [
            nhi: result/1/1
        ]
      ] else [
        nhi: "-ERR Didn't parse the parser"
      ]
      return reduce [200 mime/html spaced["id:" nhi]]
    ]

    parse? req/request-uri  ["/patients/" copy id some digit "/all/" end][
        print "parsed fetch-all"
        id: to integer! id
        sql-execute [{select nhi from NHILOOKUP where id =} ^id]
        result: copy port
        if empty? result [
          return spaced [{-ERR this ID of:} id {is not in use}]
        ] else [
          fetch-all to integer! id result/1/1
        ]
    ]
  ]

  set 'request req  ; global 
  req/target: my dehex
  path-elements: next split req/target #"/"
  ; 'extern' url /http://ser.ver/...
  parse req/request-uri ["//"] then [
    lib/print req/request-uri
    return reduce [200 mime/html "req/request-uri"]
  ] else [
    path: join root-dir req/target
    path-type: try exists? path
  ]
  append req reduce ['real-path clean-path path]
  if path-type = 'dir [
    if not access-dir [return 403]
    if req/query-string [
      if data: html-list-dir path [
        return reduce [200 mime/html data]
      ] 
      return 500
    ]
    if file? access-dir [
      for-each ext [%.reb %.rem %.html %.htm] [
        dir-index: join access-dir ext
        if 'file = try exists? join path dir-index [
          if ext = %.reb [append dir-index "?"]
          break
        ]
      ] then [dir-index: "?"]
    ] else [dir-index: "?"]
    return redirect-response join req/target dir-index
  ]
  if path-type = 'file [
    pos: try find-last last path-elements
      "."
    file-ext: (if pos [copy next pos] else [_])
    mimetype: try attempt [ext-map/:file-ext]
    if trap [data: read path] [return 403]
    if all [
      any [
        mimetype = 'rem
        all [
          mimetype = 'html
          "REBOL" = uppercase to-text copy/part data 5
        ]
      ]
      action? :rem-to-html
      any [
        not req/query-string
        not empty? req/query-string 
      ]
    ][
      rem/rem/request: req
      if error: try trap [
        data: rem-to-html data
      ] [ data: form error mimetype: 'text ]
      else [ mimetype: 'html ]
    ]
    if mimetype = 'rebol [
      if req/query-string [
        mimetype: 'html
        e: try trap [
          data: do data
        ]
        if all [not error? e, action? :data] [
          e: try trap [
            data: data req
          ]
        ]
        if error? e [data: e]
        case [
          block? :data [
            mimetype: first data
            data: next data
          ]
          quoted? :data [
            data: form eval data
            mimetype: 'text
          ]
          error? :data [mimetype: 'text]
        ]
        data: form :data
      ] else [mimetype: 'text]
    ]
    return reduce [200 try select mime :mimetype data]
  ]
  404
]

redirect-response: function [target] [
  reduce [200 mime/html unspaced [
    {<html><head><meta http-equiv="Refresh" content="0; url=}
    target {" /></head></html>}
  ]]
]

;; MAIN
server: open compose [
  scheme: 'httpd (port) [
    if verbose >= 2 [lib/print mold request]
    if verbose >= 1 [
      lib/print spaced [
        request/method
        request/request-uri
      ]
    ]

    ; !!! This is a hook inserted for purposes of being
    ; able to know if a screenless emulator is running
    ; the console correctly.  /data/local/tmp is a special
    ; writable folder in Android.
    ;
    ; https://github.com/metaeducation/rebol-server/issues/9
    ; 
    trap [
      uparse request.target [
        "/testwrite" across thru end
      ] then testfile -> [
        write as file! testfile "TESTWRITE!"
        res: reduce [
          200
          "text/html"
          unspaced [<pre> testfile _ "written" </pre>]
        ]
      ] else [
        res: handle-request request
      ]
    ] then err -> [  ; handling (or testwrite) failed
      res: reduce [
        200
        "text/html"
        unspaced [<pre> mold err </pre>]
      ]
    ]

    if integer? res [
      response/status: res
      response/type: "text/html"
      response/content: unspaced [
        <h2> res space select status-codes res </h2>
        <b> request/method space request/request-uri </b>
        <br> <pre> mold request </pre>
      ]
    ] else [
      response/status: res/1
      response/type: res/2
      response/content: to-binary res/3
    ]
    if verbose >= 1 [
      lib/print spaced ["=>" response/status]
    ]
  ]
]

import %patientdb/sql.reb

; type Script id unassigned-attach message arg1 word is attached to a context, but unassigned near *** copy  foreach ** nhi common ?? nhi id *** *** where fetch-combo-users either if handle-request else trap handler if dispatch case cycle accept wait do catch module import* do* do console file /D/webserver.reb line 355 arg1 foreach

fetch-combo-users: func [drug
  <local> id drug1 drug2 common drugs drug-1 drug-2
][
  drugs: split drug "+"
  append drugs/1 "%" drugs-1: drugs/1
  append drugs/2 "%" drugs-2: drugs/2

;comment {
  insert port [
    {select nhi from medications where name like (?) and active = 'T'} drugs/1
  ]

  drug1: copy port

  insert port [
    {select nhi from medications where name like (?) and active = 'T'} drugs/2
  ]

  drug2: copy port

  common: intersect drug1 drug2 ; [[n] [n2] [n3]]
  ; probe common

  combos: copy []
;}

  ; get the patients on drug-1 eg. MTX
    ; id: common/1/1

    insert port [
    {
      select distinct nhilookup.nhi, nhilookup.id, patients.surname, patients.fname, 
      patients.phone, patients.mobile, patients.street, patients.town, patients.gpname, patients.gpcentname,
      medications.letter, medications.name, medications.dosing  
      from medications, nhilookup, patients
      where nhilookup.id = medications.nhi
      and patients.nhi = medications.nhi
      and medications.name like (?)
      and medications.active = 'T'
      and patients.nhi in (select distinct nhi from medications where active = (?) and name like (?))
    } drugs-1 "T" drugs-2
    ]
    rec: copy port
    for-each r rec [
        d: r/11
        if date? d [
          r/11: form d/date
        ]
    ]
; comment {    
    ;?? drugs-2
    ;print "number of results"
    ;probe length? rec
    ;probe rec
    for-each r rec [
      ; get the second drug, patient id is r/2
      ; probe r
      id: r/2
      insert port [{select distinct nhi, name, dosing from medications where nhi = (?) and name like (?) and active = 'T'} id drugs-2 ]
      s: copy port
      append r reduce [s/1/2 s/1/3]
    ]
;}
    append/only rec []
    insert/only rec ["NHI" "ID"  "Surname" "FirstName" "Phone" "Mobile" "Street" "Town" "FP" "Med Centre" "ClinicDate" "Medication-1" "Dose-1" "Medication-2" "Dose-2"]
    ; probe rec
    append combos rec
    ; insert combos drug

  ; probe mold combos
  return mold combos
]


fetch-drug-users: func [drug][

  patient-ids: copy []
  ;foreach drug drugs [
  ;probe drug
  append drug "%"
  insert port [
    {select distinct nhilookup.nhi, patients.surname, patients.fname, medications.letter, medications.name, medications.dosing, 
    patients.phone, patients.mobile, patients.street, patients.town, patients.gpname, patients.gpcentname 
     from medications, nhilookup, patients
      where nhilookup.id = medications.nhi
      and patients.nhi = medications.nhi
      and medications.name like (?) 
      and medications.active = 'T' 
    } drug
  ]
  ; [integer! date! string! string!]
  for-each record copy port [
    attempt [record/4: form record/4/date]
    append/only patient-ids record
  ]
  ;]
  if not empty? patient-ids [
    insert/only patient-ids ["NHI" "Surname" "FirstName" "ClinicDate" "Drug" "Dosing" "Phone" "Mobile" "Street" "Town" "FP" "MedicalCentre"]
    ; append/only patient-ids []
    probe mold patient-ids
  ] else [
    append patient-ids spaced ["Query for" drug "returned no results"]
  ]
  return mold patient-ids
]

fetch-all: func [dbid nhi
  <local> rec
][
    print "entering fetch all"
    sql-execute [{select fname, surname, dob, gpname, gpcentname, phone, mobile, street from patients where nhi =} ^dbid]
    rec: copy port
    if not empty? rec [
			rec: rec/1
			patient-o: make object! compose [
				fname: (rec/1)
				surname: (rec/2)
				dob: (rec/3)
				gpname: rec/4
				gpcentname: (rec/5)
				dbid: (dbid)
				nhi: (nhi)
				phone: rec/6 mobile: rec/7
				street: rec/8
				medications: diagnoses: dmards: consults: dates: _
			]
			; now let us get the number of medications
			medications: copy []
			sql-execute [{select name, dosing from medications where active = 'T' and nhi =} ^dbid]
			rec: copy port
			if not empty? rec [
				for-each r rec [
					append medications spaced [r/1 r/2]
				]
			]

			; diagnoses
			diagnoses: copy []
			sql-execute [{select diagnosis from diagnoses where nhi =} ^dbid]
			rec: copy port
			if not empty? rec [
				for-each r rec [
					append diagnoses r/1
				]
			]

			dmards: copy []
      dump dbid
			sql-execute [{select name, dosing from medications where active = 'F' and nhi =} ^dbid]
			rec: copy port
			if not empty? rec [
				for-each r rec [
					append dmards r/1
				]
			]

			patient-o/dmards: unique dmards
			patient-o/medications: unique medications
			patient-o/diagnoses: unique diagnoses

			rdates: copy [] dates: copy [] consults: copy []
			sql-execute [{select id, cdate, clinicians, dictation from letters where nhi =} ^dbid {order by cdate DESC} ]
			for-each record copy port [
				append/only consults record ; id cdate clinicians dictation
				; append rdates rejoin [next form 100000 + record/1 " " record/2]
				append dates form record/2
			]

			patient-o/dates: dates
			patient-o/consults: consults
			return mold patient-o
		] else [
      return {-ERR patient not found}
    ]
]

if verbose >= 1 [
  lib/print spaced ["Serving on port" port]
  lib/print spaced ["root-dir:" clean-path root-dir]
  lib/print spaced ["access-dir:" mold access-dir]
  lib/print spaced ["dsn:" dsn]
]

wait server

;; vim: set et sw=2:

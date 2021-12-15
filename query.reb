rebol []

import %sql.reb

fetch-all: func [dbid nhi
  <local> rec
][
    print "entering fetch all"
    sql-execute [
      SELECT fname, surname, dob, gpname, gpcentname, phone, mobile, street
      FROM patients where nhi = @dbid
    ]
    rec: copy port
    if not empty? rec [
      rec: rec.1
      patient-o: make object! compose [
        fname: (rec.1)
        surname: (rec.2)
        dob: (rec.3)
        gpname: rec.4
        gpcentname: (rec.5)
        dbid: (dbid)
        nhi: (nhi)
        phone: rec.6 mobile: rec.7
        street: rec.8
        medications: diagnoses: dmards: consults: dates: _
      ]
      ; lets get dmards which are inactive drugs
      dmards: copy []
      dump dbid
      sql-execute [
        SELECT name, dosing
        FROM medications
        WHERE nhi = @dbid and active = {'F'} 
      ]
      rec: copy port
      if not empty? rec [
        for-each r rec [
          append dmards r.1
        ]
      ]

      ; now let us get the number of medications

      medications: copy []
      sql-execute [
        SELECT name, dosing
        FROM medications
        WHERE nhi = @dbid and active = {'T'}
      ]
      rec: copy port
      if not empty? rec [
        for-each r rec [
          append medications spaced [r.1 r.2]
        ]
      ]

      ; diagnoses
      diagnoses: copy []
      sql-execute [
        SELECT diagnosis
        FROM diagnoses
        WHERE nhi = @dbid
      ]
      rec: copy port
      if not empty? rec [
        for-each r rec [
          append diagnoses r.1
        ]
      ]

      patient-o.dmards: unique dmards
      patient-o.medications: unique medications
      patient-o.diagnoses: unique diagnoses

      rdates: copy [] dates: copy [] consults: copy []
      sql-execute [
        SELECT id, cdate, clinicians, dictation
        FROM letters
        WHERE nhi = @dbid
        ORDER BY cdate DESC
      ]
      for-each record copy port [
        append/only consults record ; id cdate clinicians dictation
        ; append rdates rejoin [next form 100000 + record.1 " " record.2]
        append dates form record.2
      ]

      patient-o.dates: dates
      patient-o.consults: consults
      return mold patient-o
    ] else [
      return {-ERR patient not found}
    ]
]

import <json>

probe to-json fetch-all 2 "VLE4321"

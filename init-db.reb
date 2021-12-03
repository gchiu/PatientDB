Rebol [
	file: %init-db.reb
	purpose: {clears existing tables if present and then loads with some initial data ready for importing}
	date: 3-Dec-2021
	author: "Graham Chiu"
    version: 0.0.2
    notes: {
        3.12.2021 first working version
    }
]

dbase: open join odbc://rebol-firebird ";UID=test;PWD=test-password"]
port: odbc-statement-of dbase
show-sql?: true

sql-execute: specialize :odbc-execute [; https://forum.rebol.info/t/1234
	statement: port
	verbose: if show-sql? [#]
]

sql-silent-execute: specialize :odbc-execute [; https://forum.rebol.info/t/1234
	statement: port
	verbose: if false [#]
]

find-table: func [tablename [text!] /silent] [
	if silent [
		sql-silent-execute {SELECT RDB$RELATION_NAME FROM RDB$RELATIONS WHERE (RDB$SYSTEM_FLAG <> 1 OR RDB$SYSTEM_FLAG IS NULL) AND RDB$VIEW_BLR IS NULL ORDER BY RDB$RELATION_NAME;}
	] else [
		sql-execute {SELECT RDB$RELATION_NAME FROM RDB$RELATIONS WHERE (RDB$SYSTEM_FLAG <> 1 OR RDB$SYSTEM_FLAG IS NULL) AND RDB$VIEW_BLR IS NULL ORDER BY RDB$RELATION_NAME;}
	]
	for-each record copy port [
		if tablename = trim record/1 [
			print spaced ["found" tablename]
			return true
		]
	]
	return false
]

drop-table: function [tablename [text!]] [
	sql-execute [{drop table} tablename]
]

drop-existing-table: func [tablename [text!]] [
	if find-table tablename [
		drop-table tablename
	]
]

if equal? "Yes" ask ["Delete all the data from patients database? (Yes/No) " text!] [
	print "start deleting"
	for-each table ['patients 'nhilookup 'files 'clinicians 'fps 'letters 'medications 'diagnoses 'gpcentre 'vaccinations] [
		; drop-existing-table form table
		trap [
			sql-execute join {drop table } table
		]
	]
	print "Finished table deletes"
] else [
    print "tables unchanged"
    quit
]

; check for successful deletion
for-each table ['patients 'nhilookup 'files 'clinicians 'fps 'letters 'medications 'diagnoses 'gpcentre] [
	if find-table/silent form table [
		print spaced ["table" table "exists!"]
	] else [
		print spaced ["table" table "deleted!"]
	]
]

; sql-execute {commit}
; insert port {commit}

; we are not going to use the NHI as the id but a unique integer
; NHI format is 3 alpha 4 integer
; insert port {create table nhilookup ( id integer generated by default as identity primary key, "NHI" CHAR(7) UNIQUE NOT NULL)}

if error? e: entrap [
	sql-execute {select count(*) from nhilookup}
	print "should give error here!"
	probe copy port
] [
	probe e
	print "this is correct, there should not be a nhilookup table now"
]

sql-execute {create table nhilookup ( id integer generated by default as identity primary key, "NHI" CHAR(7) UNIQUE NOT NULL)}

; dummy data
;insert port {insert into nhilookup (nhi) values ('MZK1240')}
;insert port {insert into nhilookup (nhi) values ('abc1234')}
;insert port {insert into nhilookup (nhi) values ('efg1923')}

insert port
{create table clinicians ( id integer generated by default as identity primary key, surname varchar(128), fname varchar(128), clintype int, registration int)}

; real rheumatology data
cns: 2 dr: 1
staff: reduce [
	"Chiu" "Graham" dr
	"Elasir" "Haitham" dr
	"Porten" "Lauren" cns
	"Sawyers" "Stephen" dr
	"Hawke" "Sonia" cns
]

for-each [surname firstname t] staff [
	cmd: unspaced [{insert into clinicians (surname, fname, clintype) values ('} surname {','} firstname {',} t {)}]
	sql-execute cmd
]

unset 'cns
unset 'dr
unset 'staff

; add consults
; id int, clinician id, date timestamp, text blob_e, checksum 
insert port
{
        create table letters (
            id integer generated by default as identity primary key,
            clinicians integer,
            nhi integer,
            cdate date,
            dictation blob sub_type text,
            checksum char(43),
            unique(checksum)
        )
    }

; add patients
insert port
{
        create table patients (
            id integer generated by default as identity primary key,
            created timestamp default current_timestamp,
            nhi integer,
            clinicians integer,
            dob date,
            gender char(1),
            pronoun char(4),
            surname varchar(128),
            fname varchar(128),
            sname varchar(128),
            street varchar(256),
            street2 varchar(256),
            town varchar(256),
            areacode integer,
            email varchar(128),
            phone varchar(15),
            mobile varchar(15),
            gp integer,
            gpcentre integer,
            gpname varchar(128),
            gpcentname varchar(128),
            deceased boolean default false,
            discharged boolean default false
        )
    }

; vaccination database - where record the vaccines given

insert port
{
        create table vaccinations (
            id integer generated by default as identity primary key,
            created timestamp default current_timestamp,
            nhi integer,
            vaccineid integer,
            outcome varchar(128),
            vaxdate date
        )    
    }


print "table init completed"
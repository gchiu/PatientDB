Rebol []

dbase: open odbc://patients
port: first dbase

; we are not going to use the NHI as the id but a unique integer
; NHI format is 3 alpha 4 integer

; attempt [insert port {drop table nhilookup}]
insert port ['tables "NHILOOKUP"] ;'
if none? pick port 1 [
    insert port {create table nhilookup ( id integer generated by default as identity primary key, "NHI" CHAR(7) UNIQUE NOT NULL)}
    ; dummy data
    ;insert port {insert into nhilookup (nhi) values ('MZK1240')}
    ;insert port {insert into nhilookup (nhi) values ('abc1234')}
    ;insert port {insert into nhilookup (nhi) values ('efg1923')}

]

;insert port {select * from NHILOOKUP}

;foreach nhis copy port [probe nhis]

; create the clinicians database
; id int surname var 128 fname varchar 128 clintype (1 = doc, 2 = cns) registration int

insert port ['tables "CLINICIANS"] ;'

if none? pick port 1 [
    insert port {create table clinicians ( id integer generated by default as identity primary key, 
        surname varchar(128),
        fname varchar(128),
        clintype int,
        registration int  
    )}
    ; real rheumatology data
    insert port {insert into clinicians ( surname, fname, clintype) values ('Chiu', 'Graham', 1)}
    insert port {insert into clinicians ( surname, fname, clintype) values ('Elasir', 'Haitham', 1)}
    insert port {insert into clinicians ( surname, fname, clintype) values ('Porten', 'Lauren', 2)}
    insert port {insert into clinicians ( surname, fname, clintype) values ('Sawyers', 'Stephen', 1)}
]

; add consults
; id int, clinician id, date timestamp, text blob_e, checksum 

insert port ['tables "letters"] ;'
if none? pick port 1 [
    insert port {
        create table letters (
            id integer generated by default as identity primary key,
            clinicians integer,
            cdate date,
            dictation blob sub_type text,
            checksum char(43)
        )
    }
]

; add patients
insert port ['tables "patients"] ;'
if none? pick port 1 [
    insert port {
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
            deceased boolean default false,
            discharged boolean default false
        )
    }

]

; vaccination database - where record the vaccines given

insert port ['tables "vaccinations"] ;' 
if none? pick port 1 [
    insert port {
        create table vaccinations (
            id integer generated by default as identity primary key,
            created timestamp default current_timestamp,
            nhi integer,
            vaccineid integer,
            outcome varchar(128),
            vaxdate date
        )    
    }
]

; GP medical centres

insert port ['tables "gpcentre"] ;'
if none? pick port 1 [
    insert port {
        create table gpcentre (
            id integer generated by default as identity primary key,
            centrename varchar(128),
            street varchar(128),
            street2 varchar(128),
            town varchar(128),
            city varchar(128),
            phone varchar(15),
            fax varchar(15),
            email varchar(128),
            edi varchar(128)
        )
    }
]

; GPs

insert port ['tables "fps"] ;' general practitioners and nurse practitioners
if none? pick port 1 [
    insert port {
        create table fps (
            id integer generated by default as identity primary key,
            title char(4),
            fname varchar(128),
            surname varchar(128),
            email varchar(128),
            registration integer
        )
    }

]



; vaccines which we use
insert port ['tables "vaccines"] ;' eg. pfizer/biontech covid-19
if none? pick port 1 [
    insert port {
        create table vaccines (
            id integer generated by default as identity primary key,
            created timestamp default current_timestamp,
            name varchar(128),
            vaxdate date
        )    
    }
]

; medications - not normalised (yet)
insert port ['tables "medications"] ;' because drugs are written differently we can normalise this latter open
if none? pick port 1 [
    insert port {
        create table medications (
            id integer generated by default as identity primary key,
            created timestamp default current_timestamp,
            letter date,
            nhi integer,
            startdate date,
            finishdate date,
            name varchar(128),
            dosing varchar(128),
            outcome varchar(256),
            active char(1)
        )
    }
]

; diagnoses - not using icd10 or anything since not standardised in the letters
insert port ['tables "diagnoses"] ;' we need to normalise these
if none? pick port 1 [
    insert port {
        create table diagnoses (
            id integer generated by default as identity primary key,
            created timestamp default current_timestamp,
            letter date,
            nhi integer,
            diagnosis varchar(256),
            detail varchar(512),
            icd10am char(7)
        )
    }
]

; files - filenames, should be unique; nhi-doc-yyyymmdd.txt

insert port ['tables "files"] ;' oddly this is still allowing duplicate filenames even though the field is specified as unique
if none? pick port 1 [
    insert port {
        create table files (
            id integer generated by default as identity primary key,
            done BOOLEAN default FALSE,
            filename varchar(32),
            UNIQUE (filename)
        )
    }
]

; once we notify the patient, we make an entry here
; mode 0=email, 1=phone, 2=letter, 3=by fp
insert port ['tables "notifications"] ;' 
if none? pick port 1 [
    insert port {
        create table notifications (
            id integer generated by default as identity primary key,
            created timestamp default current_timestamp,
            nhi integer,
            ndate timestamp,
            clinicians integer,
            mode integer,
            notes varchar(128)
        )
    }
]


close port

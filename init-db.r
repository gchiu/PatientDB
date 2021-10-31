Rebol []

dbase: open odbc://patients
port: first dbase

; we are not going to use the NHI as the id but a unique integer
; NHI format is 3 alpha 4 integer
insert port {create table NHILOOKUP ( id integer generated by default as identity primary key, "NHI" CHAR(7) UNIQUE NOT NULL)}

insert port {insert into nhilookup (nhi) values ('MZK1240')}
insert port {insert into nhilookup (nhi) values ('abc1234')}
insert port {insert into nhilookup (nhi) values ('efg1923')}

insert port {select * from NHILOOKUP}

foreach nhis copy port [probe nhis]

close port

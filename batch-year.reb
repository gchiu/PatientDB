Rebol [
	date: 4-Nov-2021
	author: "Graham Chiu"
	purpose: {Setup all the 3 years directories with all the docx files already converted to txt and then calls
		read-files to grab all the file names, and then parse-letter to extract all the information in the letters
		which is then uploaded to the database
	}
    notes: {
        4.12.2021 ported to renc

    }
]

; for-each f read %./ [dump f orig: copy f if find f "111" [replace f "111" "11" dump f rename orig f]]

earliest-year: 2018 ;  actually it's 2019
years: []
n: now/year

until [append years n, n: me - 1, n = 2018]

months:  ["December" "November" "October" "September" "August" "July" "June" "May" "April" "March" "February" "January"]

; months: ["October"] years: [2021]

t1: now/precise
for-each year years [
	for-each cmonth months [
		do/args %read-files.reb  dir: to file! unspaced ["/d/" year "/" year "/" cmonth "/"]
		; do/args %read-files.reb  dir: to file! unspaced [year "/" year "/" cmonth "/"]
		print "invoking parse-letters.reb"
		do/args %parse-letter.reb dir
	]
]
t2: now/precise
print spaced ["took" difference t2 t1]

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

earliest-year: 2018 ;  actually it's 2019
years: []
n: now/year

until [insert years n, n: me - 1, n = 2018]

months:  ["December" "November" "October" "September" "August" "July" "June" "May" "April" "March" "February" "January"]

months: ["October"]
years: [2021]

for-each year years [
	for-each cmonth months [
		do/args %read-files.reb  dir: to file! unspaced [year "/" year "/" cmonth "/"]
		do/args %parse-letter.reb dir
	]
]

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

years:  ["December" "November" "October" "September" "August" "July" "June" "May" "April" "March" "February" "January"]

for-each cmonth years [
	dir: to file! unspaced [%2021/2021/ cmonth "/"]
	do %read-files.reb
	do %parse-letter.reb
]

for-each cmonth years [
	dir: to file! unspaced [%2020/2020/ cmonth "/"]
	do %read-files.reb
	do %parse-letter.reb
]

for-each cmonth years [
	dir: to file! unspaced [%2019/2019/ cmonth "/"]
?? dir
	do %read-files.reb
	do %parse-letter.reb
]

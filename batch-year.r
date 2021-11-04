Rebol [
	date: 4-Nov-2021
	author: "Graham Chiu"
	purpose: {Setup all the 3 years directories with all the docx files already converted to txt and then calls
		read-files to grab all the file names, and then parse-letter to extract all the information in the letters
		which is then uploaded to the database
	}
]

y2021: ["October" "September" "August" "July" "June" "May" "April" "March" "February" "January"]
years:  ["December" "November" "October" "September" "August" "July" "June" "May" "April" "March" "February" "January"]

foreach cmonth y2021 [
	dir: rejoin [%2021/2021/ cmonth "/"]
	do %read-files.r
	do %parse-letter.r 
]

foreach cmonth years [
	dir: rejoin [%2020/2020/ cmonth "/"]
	do %read-files.r
	do %parse-letter.r 
]

foreach cmonth years [
	dir: rejoin [%2019/2019/ cmonth "/"]
?? dir
	do %read-files.r
	do %parse-letter.r 
]

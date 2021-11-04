Rebol [

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

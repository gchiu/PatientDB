Rebol [

]

y2021: ["October" "September" "August" "July" "June" "May" "April" "March" "February" "January"]
year:  ["December" "November" "October" "September" "August" "July" "June" "May" "April" "March" "February" "January"]

foreach month y2021 [
	dir: rejoin [%2021/2021/ month "/"]
	do %read-files.r
	do %parse-letter.r 
]

foreach month year [
	dir: rejoin [%2020/2020/ month "/"]
	do %read-files.r
	do %parse-letter.r 
]

foreach month year [
	dir: rejoin [%2019/2019/ month "/"]
?? dir
	do %read-files.r
	do %parse-letter.r 
]

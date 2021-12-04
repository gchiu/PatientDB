Rebol [
	file: %make-directories.reb
	notes: {create the directories that are normally created by unzipping the patient letter directories}
]

years: [2019 2020 2021]
months: ["December" "November" "October" "September" "August" "July" "June" "May" "April" "March" "February" "January"]

for-each year years [
	year-directory: to file! unspaced [year "/" year "/"]
	for-each month months [
		month-directory: join year-directory month
		if not exists? month-directory [
			print unspaced ["making" month-directory]
			mkdir/deep month-directory
		]
	]
]
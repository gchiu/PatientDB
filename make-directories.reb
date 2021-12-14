Rebol [
    file: %make-directories.reb
    notes: {create the directories that are normally created by unzipping the patient letter directories}
]

earliest-year: 2018 ;  actually it's 2019
years: []
n: now/year

until [insert years n, n: me - 1, n = 2018]

months: ["December" "November" "October" "September" "August" "July" "June" "May" "April" "March" "February" "January"]

for-each year years [
    year-directory: to file! unspaced [year "/" year "/"]
    for-each month months [
        month-directory: join year-directory month
        if not exists? month-directory [
            print spaced ["making" month-directory]
            mkdir/deep month-directory
        ]
    ]
]

; let's confirm our test letters are here
cd %2021/2021/October/
ls

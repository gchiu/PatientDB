Rebol [
    file: %check.reb
    purpose: {
        checks to make sure that the data in the tables is expected

    }

]

import %sql.reb

    dump-table 'patients
    dump-table 'files
    dump-table 'letters
    dump-table 'diagnoses
    dump-table 'medications


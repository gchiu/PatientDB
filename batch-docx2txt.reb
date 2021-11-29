Rebol [
	file: %batch-docx2txt.reb
	notes: {converts all the docx in a directory to txt if not already present}
	date: 29-Nov-2021
]

import %markup.reb

load-docx: function [
	docx [file!]
] [
	t: make block! 24
	unzip/quiet t docx
	; xml is defined in %markup.reb
	xml/load select t %"word/document.xml"
]

batch-docx2txt: func [dir [file!]
	<local> files d t
] [
	if not dir? dir [
		print "not a directory!"
		exit
	]
	files: read dir
	for-each file files [
		if %.docx = suffix? file [
			target: join dir replace copy file %.docx %.txt
			if not exists? target [
				print spaced ["converting" target]
				t: load-docx join dir file

				d: copy ""
				for-each [k v] t [
					if k = 'text [
						print "writing"
						write-stdout v
						append d deline v ;== remove CRLF pairs and replace with LF
					]
					if all [k = 'vtag, block? v, v/1 = <w:tab>] [
						write-stdout "^-"
						if #"^/" <> last d [
							append d "^-"
						]
					]
					if all [k = 'ctag, v = <w:p>] [
						print ""
						append d "^/"
					]
				]

				target: open/new target
				write/append target d
				close target

			] else [
				print spaced ["skipping" target]
			]
		]
	]
]

batch-docx2txt %/d/2021/2021/November/
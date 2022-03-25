#!/bin/bash

locales=( $(ls -1 *.txt | gawk 'match($0, /[a-zA-Z0-9]+_([a-zA-Z]+)\.txt/, a) {print a[1]}' | sort | uniq) )
locales=("${locales[@]/pw}")
echo ${locales[@]}
games=( $(ls -1 *.txt | gawk 'match($0, /([a-zA-Z0-9]+)_[a-zA-Z]+\.txt/, a) {print a[1]}' | sort | uniq) )

echo "Chat translations">"collected.txt"
for locale in ${locales[@]}; do
	echo "Collecting ${locale}..."
	echo "----------------------------------------">>"collected.txt"
	for game in ${games[@]}; do
		filename="${game}_${locale}.txt"
		if [[ -e $filename ]]; then
			echo "  ${locale}  ${game}">>"collected.txt"
			iconv -f `enca -i -L none $filename` -t utf-8 $filename | grep -Pi '^\s*"?[a-z0-9]+(?<!party)_chat_' | sed 's/^\s*\(.*[^ \t]\)\(\s\+\)*$/\1/' >>"collected.txt"
		fi
	done
done

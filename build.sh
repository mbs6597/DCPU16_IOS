rm -f raw_output* compiled_output* output*

headers=$(find . -name '*.h')
asmfiles=$(find . -name '*.S')
sections=( RAW TEXT DATA BSS )

filtersection() {
	lastSection=""

	echo ":$1_SECTION_START"
	
	while read line
	do

	if [[ "$line" == *_SECTION ]]
	then
		lastSection="$line"
	else
		if [[ "$lastSection" == "$1_SECTION" ]]
		then
			echo $line
		fi
	fi
	
	done < $2
	
	echo ":$1_SECTION_END"
}

echo ";GENERATED FILE. DO NOT EDIT" > raw_output
for f in $headers
do
	echo "adding header:" $f
	cat $f >> raw_output
	echo >> raw_output
done

for f in $asmfiles
do
	echo "adding asm file:" $f
	cat $f >> raw_output
	echo >> raw_output
done

mv raw_output raw_output.S

gcc -P -E raw_output.S | sed s/»/\\n/g >> compiled_output


for section in "${sections[@]}"
do
	filtersection $section compiled_output >> output.S
done

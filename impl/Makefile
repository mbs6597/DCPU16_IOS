output.S: kernel.S offsets.S kernel_text.S kernel_bss.S
	echo ";DO NOT EDIT. THIS FILE IS GENERATED" > output.S
	gcc -P -E kernel.S | sed s/»/\\n/g >> output.S
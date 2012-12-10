output.S: kernel.S offsets.S kernel_text.S kernel_bss.S
	gcc -P -E kernel.S | sed s/»/\\n/g > output.S
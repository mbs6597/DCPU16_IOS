TEXT_SECTION
:procs_func 
	set z, 2
	set z, 2
	set z, 2
	set z, 2
	set z, 2
	set z, 2
	set z, 2
	set z, 2

	jsr [SYS_YIELD]
	set pc, procs_func
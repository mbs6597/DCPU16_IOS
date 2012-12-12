TEXT_SECTION
:loader_func 
	set z, 1
	set z, 1
	set z, 1
	set z, 1
	set z, 1
	set z, 1
	jsr [SYS_YIELD]
	set pc, loader_func
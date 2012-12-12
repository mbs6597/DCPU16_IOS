TEXT_SECTION
:init_func 
	set a, [SYS_ALLOC]
	set b, 1
	set x, 740
	set y, [SYS_CURRENT]
	
	set push, 0
	set push, 0
	
	set z, sp

	jsr [SYS_MSG]
	
	set a, sp
	jsr [SYS_WFCOMP]
	
:init_end
	jsr [SYS_YIELD]
	set z, 4
	set pc, init_end

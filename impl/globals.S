;                                                                             ;
;  System Globals - Variables used in place by all processes                  ;
;                                                                             ;
RAW_SECTION
	set pc, kickoff

:SYS_YIELD
	dat sys_yield_fn

:SYS_MSG
	dat sys_msg_fn

:SYS_WFCOMP
	dat sys_wfcomp_fn

:SYS_GETMSG
	dat sys_getmsg_fn

:SYS_COMP
	dat sys_comp_fn

:SYS_ALLOC
	dat pid_alloc

:SYS_PROCS
	dat pid_procs

:SYS_LOADER
	dat pid_loader

:SYS_CURRENT
	dat 0

	 
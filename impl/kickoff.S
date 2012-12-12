;                                                                             ;
;  Kickoff Section - Functions used to bootstrap the proccess contexts        ;
;                                                                             ;
TEXT_SECTION

;kickoff:
;Preconditions: None
;Postconditions: System processes are initialized and the init task is running.
:kickoff
	;setup core PID structs
	set i, pid_alloc
	set x, namealloc
	set y, allocstack_end-1
	set j, 0
	
	jsr mkblankproc
	
	
	set i, pid_procs
	set x, nameprocs
	set y, procsstack_end-1
	set j, pid_alloc
	
	jsr mkblankproc
	
	
	set i, pid_loader
	set x, nameloader
	set y, loaderstack_end-1
	set j, pid_procs
	
	jsr mkblankproc
	
	
	set i, pid_init
	set x, nameinit
	set y, initstack_end-1
	set j, pid_loader
	
	jsr mkblankproc

;setup initial stacks
	set [loaderstack_end-1], loader_func
	set [allocstack_end-1], alloc_func
	set [procsstack_end-1], procs_func

;dive into init process
	set [SYS_CURRENT], pid_init
	set sp, initstack_end
	set pc, init_func

:kickoff_end


;mkblankproc - Initialize a chunk of memory as a PID block
;Preconditions: 
;i = pid block to initialize
;j = pid to link after, null for self link
;x = name pointer
;y = initial stack pointer location
;Postconditions: i unchanged, j unchanged, b undefined, c undefined
;Pid block has name set, next/prev task links setup, and initial stack set.
;all other fields are zeroed out.
:mkblankproc
	set push, i
	set push, j
	set b, 32
	set c, 0
	jsr memset

	set j, pop
	set i, pop

	set [i+task_common_name], x
	set [i+task_saved_sp],    y
	
	ifn j, 0
	set pc, mkblankproc_link

	set [i+task_sched_prev], i
	set [i+task_sched_next], i
	set pc, pop

:mkblankproc_link

	set [i+task_sched_next], [j+task_sched_next]
	set [i+task_sched_prev], j

	set c, [i+task_sched_next]

	set [c+task_sched_prev], i
	set [j+task_sched_next], i

	set pc, pop

:mkblankproc_end

DATA_SECTION

:nameinit
dat "INIT",0
:namealloc
dat "ALLOC",0
:nameprocs
dat "PROCS",0
:nameloader
dat "LOADER",0


BSS_SECTION

DIM(pid_alloc, 32)

DIM(pid_procs, 32)

DIM(pid_loader, 32)

DIM(pid_init, 32)

DIM(initstack, 8)

DIM(loaderstack, 8)

DIM(procsstack, 8)

DIM(allocstack, 8)
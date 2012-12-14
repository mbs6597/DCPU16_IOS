TEXT_SECTION
:procs_func 
	jsr [SYS_GETMSG]
	
	ife a, 0
	set pc, procs_func_idle
	
	ife b, 1
	set pc, procs_func_add
	
	ife b, 2
	set pc, procs_func_remove
	
:procs_func_idle
	jsr [SYS_YIELD]
	set pc, procs_func
	
:procs_func_add
	set a, [SYS_CURRENT]
	set b, [a+task_sched_next]
	set [x+task_sched_next], b
	set [b+task_sched_prev], x
	set [a+task_sched_next], x
	set [x+task_sched_prev], a
	set pc, procs_comp
	
:procs_func_remove	
	set a, [SYS_CURRENT]
	set b, [a+task_sched_prev]
	set c, [a+task_sched_next]
	
	set [a+task_sched_next], 0
	set [a+task_sched_prev], 0
	set [b+task_sched_next], c
	set [c+task_sched_prev], b
	
:procs_comp
	set c, z
	set a, CODE_OK
	set b, ERROR_NONE
	jsr [SYS_COMP]
	set pc, procs_func_idle
	
#define NUM_TASKLETS 8
:do_tasklets
	set [tasklet_spsave], sp
	set sp, tasklet_stack
	
	set i, tasklet_tasks
	set j, 0
	
:do_tasklets_lp
	sti c, [i]
	ifn c, 0
	jsr c
	ifl j, NUM_TASKLETS+1
	set pc, do_tasklets_lp
	
	set sp, [tasklet_spsave]
	set pc, pop

:cswitch_maint
	add [cswitch_count], 1
	set pc, pop

DATA_SECTION
:tasklet_tasks
dat cswitch_maint
SPACE(8)

:cswitch_count
dat 0

BSS_SECTION

SPACE(NUM_TASKLETS)
:tasklet_stack

:tasklet_spsave
SPACE(1)
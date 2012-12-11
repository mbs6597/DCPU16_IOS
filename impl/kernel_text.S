:kernel_text_start
;                                                                             ;
;  System Globals - Variables used in place by all processes                  ;
;                                                                             ;


	set pc, kickoff

org kernel_text_start+2

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

	
;                                                                             ;
;  Kickoff Section - Functions used to bootstrap the proccess contexts        ;
;                                                                             ;


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


;                                                                             ;
;  Syscall Section - Implementations of the syscalls                          ;
;                                                                             ;

;sys_yield_fn - Give up CPU and switch context to the next linked process
;Preconditions: Running in a valid process context, meaning [SYS_CURRENT]
;points to a valid task struct.
;Postconditions: In thread-local context, all registers may have been changed.
;The A register will contain the pointer to the current process id struct.
:sys_yield_fn
	set a, [SYS_CURRENT]
	set [a+task_saved_sp], sp
	set a, [a+task_sched_next]
	set sp, [a+task_saved_sp]
	set [SYS_CURRENT], a
	set pc, pop

:sys_yield_fn_end


;sys_msg_fn - Message another process. If their queue is full this will
;yield until the message can be sent. Must be in a valid process context.
;Preconditions: A points to a valid pid struct
;Post conditiosn: The task that a pointed to will have a message in the 
;queue with the sender as the current process, message id of b,
;passed in, with parameters of x, y and z.
;Registers I,J and Ex may have changed. A, B, X, Y and Z will be the same
:sys_msg_fn
	add a, task_msg_count
	
:sys_msg_test_ct
	set c, [a]
	and c, 0xff ;lower octet = msg_qty
	
	ifl c, task_qty_messages 
	set pc, sys_msg_add_it

	;target has too many messages, yield and try again
	set push, a
	set push, b
	set push, x
	set push, y
	set push, z
	
	jsr sys_yield_fn
	
	set z, pop
	set y, pop
	set x, pop
	set b, pop
	set a, pop
	
	set pc, sys_msg_test_ct
	
:sys_msg_add_it
	;at this point c = count of messages in target
	set i, [a]
	shr i, 8         ;index of first message now in i
	
	and [a], 0xff00  ;clear message count
	add c, 1
	bor [a], c       ;set new message count
	sub c, 1
	
	add c, i       
	mod c, task_qty_messages ;c = end index in circular buffer
	mul c, msg_size          ;c*=sizeof(struct pending_msg)
	add a, (task_msg_queue-task_msg_count)                
	add a, c                 ;move pointer to entry we should fill in
	
	set [a+msg_sender],  [SYS_CURRENT]
	set [a+msg_message], b              
	set [a+msg_p1],      x              
	set [a+msg_p2],      y
	set [a+msg_p3],      z
	
	set pc, pop
	
:sys_msg_fn_end

;sys_wfcomp_fn - Wait for a completion struct to be filled in. Yielding as
;many times as necessary. Must be in a valid process context.
;preconditions: A ponts to a completion struct. The struct does not needs to be
;initialized to have a code in 0 before the condition that triggers it may have fired.
;(ie, if waiting for another process' response to a sent message, you can do it after
; the message is delivered, but before you yield. If you want to wait for an interrupt
; the code must be zeroed before the intterupt is enabled.)
;post conditions: A completion was sent to the targetd struct. B will contain
;the code, C will contain the message. A will be unchanged. All other registers
;may have changed.
:sys_wfcomp_lp
	set push, a
	jsr sys_yield_fn
	set a, pop
:sys_wfcomp_fn
	ife [a], 0
	set pc, sys_wfcomp_lp

	set b,[a]
	set c,[a+1]
	set pc, pop

:sys_wfcomp_fn_end

;sys_getmsg_fn - Return in registers the first message in the queue.
;preconditions: In a valid process context
;postconditions: If there are no messages in the current process's queue,
;A will be 0, and B will be an undefined value.
;If there is one or more messages in the queue, a will be the first message's
;sender, B will be the messsage id, x, y and z will be the three parameters.
;the current process's task queue will be modified to reflect that this message
;has been received.
:sys_getmsg_fn
	set a, [SYS_CURRENT]
	add a, 8
	set b, [a]
	and b, 0xff ;b = msg_qty
	
	ife b, 0
	set pc, sys_getmsg_nomsg
	
	set c, [a]
	shr c, 8    ;c = first_msg_index
	
	;make new first_msg_index/msg_qty variable
	set i, c
	add i, 1
	mod i, 4
	shl i, 8
	set j, b
	sub j, 1
	bor i, j
	set [a], i
	
	;find location of message
	add a, 1
	mul c, 5
	add a, c
	
	set b,[a+1]
	set x,[a+2]
	set y,[a+3]
	set z,[a+4]
	set a, [a]
	
	set pc, pop
	
:sys_getmsg_nomsg
	set a, 0
	set pc, pop

:sys_getmsg_end

;sys_comp_fn - sets a completion struct with a code and message
;preconditions: c points to a completion struct, a is nonzero.
;postconditions: targeted completion struct is marked as complete
;with code a and message b.
:sys_comp_fn
	set [c], a
	set [c+1], b
	set pc, pop
	
:sys_comp_fn_end


;                                                                             ;
;  Utility Function Section - common routines used by kernel functions        ;
;                                                                             ;


;memset - set a block of words to a single value (duffs device implementation)
;preconditions: i is the start address of memory to be initialized
;b is length to be written and c is the value to write to each word
;postconditions:
;i is 1 past last word written, B, J, Ex are undefined, all other registers
;are untouched
:memset
set pc, memset_lp_cond
:memset_lp
	sti [i], c
	sti [i], c
	sti [i], c
	sti [i], c
	sti [i], c
	sti [i], c
	sti [i], c
	sti [i], c
	sti [i], c
	sti [i], c
	sti [i], c
	sti [i], c
	sti [i], c
	sti [i], c
	sti [i], c
	sti [i], c

	sub b, 16

:memset_lp_cond
	ifa b, 15
	set pc, memset_lp

	ifu b, 1
	set pc, pop

	set push, b
	add peek, 9
	sub pc, pop

:memset_end


;                                                                             ;
;  Kernel Core Process Section - Routines run by core kernel services         ;
;                                                                             ;


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
	set pc, init_end

:alloc_func
;Have alloc claim all of the static kernel image as its own memory
	set x, kernel_bss_end
	;divide by 256 round up
	shr x, 8   
	ifn ex, 0
	add x, 1  
	
	;tag those blocks as being owned
	set i, alloc_map
	set b, x
	set c, pid_alloc
	
	jsr memset
	
	
	;add the rest to a single node in the free linked list
	;head word of of free list node = (size of free block << 8) | next free block start index
	;in this case the next free block will be null
	set [alloc_freelist], x
	
	set b, alloc_map_end-alloc_map
	sub b, x
	shl b, 8
	
	set [alloc_map+x], b
	
:alloc_loop
	jsr [SYS_GETMSG]
	
	ife a, 0
	set pc, alloc_nomsg
	
	ife b, 1
	set pc, alloc_allocate
	
	ife b, 2
	set pc, alloc_free
	
	ife b, 3
	set pc, alloc_freeall
	
	;at this point unknown message

:alloc_nomsg
:alloc_idle
	jsr [SYS_YIELD]
	set pc, alloc_loop

:alloc_allocate
;x words to allocate, y new owner, z completion struct
	set push, z
	set a, x
;calculate blocks to allocate = a/256 round up
	shr a, 8
	ifn ex, 0
	add a, 1
	
	set x, [alloc_freelist]
	set z, alloc_freelist
:alloc_allocate_lp
	;x is index of current node in array
	;z is memory address of previous node (or list head)
	
	ife a, 0
	set pc, alloc_allocate_fail
	
	;get size of current block, and next block index
	;y = size, i = next index
	set b, [alloc_map+x]
	shr b, 8
	set i, ex
	shr i, 8
	
	;will the current block be big enough?
	ifl b, x
	set pc, alloc_allocate_nextblk
	
	;will we consume the entire block?
	ife b, x
	set pc, alloc_allocate_fullblock
	
	;create new header from the current one
	sub b, x
	shl b, 8
	bor b, i
	
	;calculate next header index
	set j, x
	add j, a
	
	;store this index in the previous node's next-index-octet
	and [z], 0xFF00
	bor [z], j
	
	;store the new header in the new index
	set [alloc_map+j], b
	
	set z, pop
	set pc, alloc_allocate_complete
	
:alloc_allocate_fullblock
	;skip this block entirely by setting previous' next to our next
	and [z], 0xFF00
	bor [z], i
	
:alloc_allocate_complete
	;x: number of blocks allocated
	;y: new owner
	;z: completion struct
	;a: index of first free block allocated
	
	;call memset
	set c, y
	set b, a
	set i, x
	add i, alloc_map
	
	jsr memset
	
	set a, 1
	set b, x
	shl b, 8
	set c, z
	
	jsr [SYS_COMP]
	
	set pc, alloc_idle
	
:alloc_allocate_nextblk
	;move onto next block
	set z, alloc_map
	add z, x
	set x, i
	
	set pc, alloc_allocate_lp

:alloc_allocate_fail
	set a, 3 ;code = EXECUTION_ERROR
	set b, 3 ;message = resource unavailable
	jsr [SYS_COMP]
	set pc, alloc_idle
	
:alloc_free
:alloc_freeall

set pc, alloc_idle


:procs_func 
	set a, a
	set a, a
	set a, a
	set a, a
	set a, a
	set a, a
	jsr [SYS_YIELD]
	set pc, procs_func

:loader_func 
	set a, a
	set a, a
	set a, a
	set a, a
	set a, a
	set a, a
	jsr [SYS_YIELD]
	set pc, loader_func


;                                                                             ;
;  Data Section - Raw data used by the kernel                                 ;
;                                                                             ;

:nameinit
dat "INIT",0
:namealloc
dat "ALLOC",0
:nameprocs
dat "PROCS",0
:nameloader
dat "LOADER",0

:kernel_text_end
;                                                                             ;
;  Syscall Section - Implementations of the syscalls                          ;
;                                                                             ;
TEXT_SECTION
;sys_yield_fn - Give up CPU and switch context to the next linked process
;Preconditions: Running in a valid process context, meaning [SYS_CURRENT]
;points to a valid task struct.
;Postconditions: In thread-local context, all registers may have been changed.
;The A register will contain the pointer to the current process id struct.
:sys_yield_fn
	jsr do_tasklets
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
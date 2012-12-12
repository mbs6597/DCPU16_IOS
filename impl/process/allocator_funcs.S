TEXT_SECTION
:alloc_func
;Have alloc claim all of the static kernel image as its own memory
	set x, BSS_SECTION_END
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
	set z, 3
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

BSS_SECTION

DIM(alloc_freelist, 1)

DIM(alloc_map, 256)


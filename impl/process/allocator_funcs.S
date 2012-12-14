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
	set a, CODE_EXECUTION_ERROR
	set b, ERROR_UNAVAILABLE
	jsr [SYS_COMP]
	set pc, alloc_idle
	
:alloc_free
;x = start of range to free, y = size, z = completion struct
	;index in table to free = address / 256 round down
	shr x, 8
	;size of freed block = size/256 round up
	shr y, 8
	ifn ex, 0
	add y, 1
	
	set a, [alloc_freelist]
	
	;is there anything in the freelist?
	ife a, 0
	set pc, alloc_free_nofreelist
	
	;is this range before the first free node?
	ifl x, a
	set pc, alloc_free_prefirst
	
	;find the node before the range
	set j, alloc_freelist
:alloc_free_lp
	;a = index of freenode
	;j = memory location of previous node
	
	set b, [a+alloc_map]
	shr b, 8
	set c, ex
	shr c, 8
	;b = size of current block, c = next index
	
	ifg c, x                      ;next node is after block that we are freeing
	set pc, alloc_free_prevfound
	
	ife c, 0                      ;there is no next node
	set pc, alloc_free_prevfound 
	
	set j, alloc_map
	add j, a
	
	set a, c
	
	set pc, alloc_free_lp

:alloc_free_prevfound
	;create this freenode header in register I
	set i, y
	shl i, 8
	bor i, c
	
	;store this node head in the map
	set [x+alloc_map], i
	
	;set the previous's next index to this node's index
	and [j], 0xFF00
	bor [j], x
	
	;run compaction with limit of 3 nodes
	set b, 3
	set pc, alloc_free_combine_nodes
	
:alloc_free_nofreelist
	;create this freenode header in register I
	set i, y
	shl i, 8
	
	;store this node head in the map
	set [x+alloc_map], i
	
	;point the list head pointer to this node
	set [alloc_freelist], x
	
	set b, 0
	set pc, alloc_free_setcomplete
	
:alloc_free_prefirst
	;create this freenode header in register I
	set i, y
	shl i, 8
	bor i, [alloc_freelist]
	
	;store this node head in the map
	set [x+alloc_map], i
	
	;set the list head pointer to this node
	set [alloc_freelist], x
	
	set b, 1
	set pc, alloc_free_setcomplete

:alloc_free_combine_nodes
;j = memory address of node to start operating on
;b = limit of nodes to operate on
;z = address of completion struct to fill in

;calculate node index into a
set a, j
sub a, alloc_map

;if we are actually on the list head pointer, skip one
ifa a, -1
set pc, alloc_free_combine_lp

set a, [j]
sub b, 1

:alloc_free_combine_lp
ifu b, 1
set pc, alloc_free_setcomplete

ife a, 0
set pc, alloc_free_setcomplete

set j, [a+alloc_map]
shr j, 8
set b, ex
shr ex, 8
;j = size of current, b = address of next

set x, j
add x, a

ifn x, b
set pc, alloc_free_combine_noaction

set i, [a+alloc_map]
set i, [i]

add i, [a+alloc_map]
and i, 0xff

and [a+alloc_map], 0xFF00
bor [a+alloc_map], i

;next iteration uses same node with larger size
sub b, 1
set pc, alloc_free_combine_lp

:alloc_free_combine_noaction
sub b, 1
set a, [a+alloc_map]
and a, 0xff
set pc, alloc_free_combine_lp

:alloc_free_setcomplete
set c, z
set a, CODE_OK
set b, ERROR_NONE

set pc, alloc_idle

:alloc_freeall

set pc, alloc_idle

BSS_SECTION

;index of the first free list node in the alloc_map pool
DIM(alloc_freelist, 1)

;head word of of free list node = (size of free block << 8) | next free block start index
;if the node isn't involved in the free-list it will contain the identifier of the owner.
DIM(alloc_map, 256)
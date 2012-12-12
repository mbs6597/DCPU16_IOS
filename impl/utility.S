;                                                                             ;
;  Utility Function Section - common routines used by kernel functions        ;
;                                                                             ;
TEXT_SECTION

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


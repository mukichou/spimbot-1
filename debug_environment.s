# -------------------------------------------------------------------------------------
# This is the SpimBot program created by Jack Abernethy, John McConnell, and Brian Xue.
#--------------------------------------------------------------------------------------

.data
state: 		.word 0			# state
next_output:	.word 0
output: 	.space 60  		# output array, 15 x 32 bits 0f 0
scan_data: 	.space 16384 		# Memory allocation for scan data

data_memory_print_str:	.asciiz "Printing data in memory: "
main_newline:		.asciiz	"\n"
main_comma:		.asciiz	", "

# euclidean stuff
three:	.float	3.0
five:	.float	5.0
PI:	.float	3.141592
F180:	.float  180.0


.text
main:
	sw	$zero,  0xffff0010($0)	# stop the bot
	la	$t0, state		# load address of state
	sw	$zero, 0($t0)		# make state == 0

	la	$t1, next_output	# load next_output address
	sw	$t0, 0($t1)		# next_output->state

	jal	initialize		# call your initialization function
					# this should set up interrupt handling;
					# all of the actual steering, etc. should
					# be done by the interrupt handler

infinite:
	jal	main_state_dispatcher 	# changes the state to 30 iff state == 0 we can use this to change the state of our machine to behave differently!
					# I will show an example below, at the end of the scanner interrupt, it store 30 to the value of state
					# this next function will check if the state is 30, if it is then the machine 'knows' it is ready to move the bot!!!
	
j	infinite			# loop forever (note that interrupts
					# will still be handled)

main_state_dispatcher:
	sub	$sp, $sp, 4		# some room for stack
	sw	$ra, 0($sp)

	la	$s0, state		# load address of state
	lw	$t0, 0($s0)		# load value of state

	li	$t1, 0			# put 32 in $t1
	li	$t2, 30
	li	$t3, 32
						# state is moved to 32 on bonks
	beq	$t0, $t1, state_zero		# if state = 32 move the bot to the next_output 32 means bot is ready to go to next token
	beq	$t0, $t2, main_move_bot_dis	# if state = 0 goto state_zero this is for bebug purposes only
	beq	$t0, $t3, sort_and_extract	
done_dispatch:				# j to this to finish dispatch
	lw	$ra, 0($sp)
	add	$sp, $sp, 4

	jr	$ra

state_zero:				# if the state is zero print 0 to help me
	# la	$a0, state
	# li	$a1, 4
	# jal	print_data_in_memory
	
	li	$t0, 5			# have state == 5
	la	$s0, state		# load address of state
	sw	$t0, 0($s0)		# load value of state
	
	j	done_dispatch

main_move_bot_dis:
	la	$s5, next_output	# load the next_output
	lw	$a0, 0($s5)
	jal	get_x_y			# get the x and y

	li    	$t1, 300                # Bound of acceptable behavior
	bgt	$v0, $t1, skip_move	# skip if not in bounds
	bgt	$v1, $t1, skip_move	# skip if not in bounds
	
	move	$a0, $v0		# x into a0
	move	$a1, $v1		# y into a1
	jal	main_move_bot

	la	$t0, state		# load state
	sw	$zero, 0($t0)		# state goes back 0
skip_move:
	la	$s5, next_output	
	lw	$t1, 0($s5)
	add	$t1, $t1, 4
	sw	$t1, 0($s5)

	j	done_dispatch
main_move_bot:
	sub     $sp, $sp, 4
      	sw      $v0, 0($sp)

	li     	$t4, 0	
	sw     	$t4, 0xffff0010($zero)	# set velocity to 10

	lw     	$t0, 0xffff0020($zero)  # get_current_x()
	lw     	$t1, 0xffff0024($zero)  # get_current_y()

	sub     $s0, $a0, $t0	       	# get difference in distance from curr_x to token
	sub     $s1, $a1, $t1	       	# get difference in distance from curr_y to token
	sub	$sp, $sp, 12
	sw	$ra, 0($sp)		# save return address on stack
	sw      $t0, 4($sp)		# saved t0 to stack
	sw      $t1, 8($sp)		# saved t1 to stack

	move	$a0, $s0	    	
	move	$a1, $s1
	jal	sb_arctan		# get the angle
	
	lw	$ra, 0($sp)		# restore return address on stack
	lw      $t0, 4($sp)		# restore t0 from stack
	lw      $t1, 8($sp)		# restore t1 from stack
	add	$sp, $sp, 12

	sw     	$v0, 0xffff0014($zero)  # set angle to new_angle
	li     	$t4, 1 
	sw     	$t4, 0xffff0018($zero)	# set orientation control = 1 (absolute)

	li     	$t4, 10	
	sw     	$t4, 0xffff0010($zero)	# set velocity to 10

	lw     	$v0, 0($sp)
	add	$sp, $sp, 4
	
	jr      $ra

get_x_y:
    	li    	$t0, 0x0000ffff         # Probably check my syntax on this one
	lw	$t1, 0($a0)
	and   	$v1, $t0, $t1           # returns 1st 16 bits as y value
	srl   	$v0, $t1, 16            # shifts right the 32 bits as x value
	jr	$ra

# -----------------------------------------------------------------
# This is the beginning of the sort and extract function
# Author: Jack Abernethy
# The labels used in the section include:
# 	sort_and_extract
# 	big_for_loop
# 	end_big_loop
# 	insert_after_element
# 	iea_after_head
# 	iea_done
# 	iea_not_head
# 	iea_not_tail
# 	remove_element
#	re_empty_list
#	re_not_empty_list
#	re_not_first
#	re_not_last
#	re_done
#	sort_list
#	sl_2_or_more
#	sl_loop
#	sl_skip
#	sl_loop_done
#	compact
#	compact_loop
#	compact_else_case
#	compact_endif
#	compact_loop_maintainance
#	compact_done
# -----------------------------------------------------------------

# args(listhead, output array head?);
#	$a0 == listhead

#---------------------------------------------------------------
#	Things needed for sort
#---------------------------------------------------------------


sort_and_extract:
	la 	$a0, scan_data
	la	$s1, output
	add	$s0, $a0, $zero		# $s0 = offset
	
	jal	sort_list
	add	$a0, $s0, $zero
	jal	compact
	sw	$v0, 0($s1)
	
	addi 	 $s0, $s0, 8
	move 	 $a0, $s0
	jal 	 sort_list
	add 	 $a0, $s0, $zero
	jal 	 compact
	addi 	 $s1, $s1, 4
	sw 	 $v0, 0($s1)
	addi 	 $s0, $s0, 8
	move 	 $a0, $s0
	jal 	 sort_list
	add 	 $a0, $s0, $zero
	jal 	 compact
	addi 	 $s1, $s1, 4
	sw 	 $v0, 0($s1)
	addi 	 $s0, $s0, 8
	move 	 $a0, $s0
	jal 	 sort_list
	add 	 $a0, $s0, $zero
	jal 	 compact
	addi 	 $s1, $s1, 4
	sw 	 $v0, 0($s1)
	addi 	 $s0, $s0, 8
	move 	 $a0, $s0
	jal 	 sort_list
	add 	 $a0, $s0, $zero
	jal 	 compact
	addi 	 $s1, $s1, 4
	sw 	 $v0, 0($s1)
	addi 	 $s0, $s0, 8
	move 	 $a0, $s0
	jal 	 sort_list
	add 	 $a0, $s0, $zero
	jal 	 compact
	addi 	 $s1, $s1, 4
	sw 	 $v0, 0($s1)
	addi 	 $s0, $s0, 8
	move 	 $a0, $s0
	jal 	 sort_list
	add 	 $a0, $s0, $zero
	jal 	 compact
	addi 	 $s1, $s1, 4
	sw 	 $v0, 0($s1)
	addi 	 $s0, $s0, 8
	move 	 $a0, $s0
	jal 	 sort_list
	add 	 $a0, $s0, $zero
	jal 	 compact
	addi 	 $s1, $s1, 4
	sw 	 $v0, 0($s1)
	addi 	 $s0, $s0, 8
	move 	 $a0, $s0
	jal 	 sort_list
	add 	 $a0, $s0, $zero
	jal 	 compact
	addi 	 $s1, $s1, 4
	sw 	 $v0, 0($s1)
	addi 	 $s0, $s0, 8
	move 	 $a0, $s0
	jal 	 sort_list
	add 	 $a0, $s0, $zero
	jal 	 compact
	addi 	 $s1, $s1, 4
	sw 	 $v0, 0($s1)
	addi 	 $s0, $s0, 8
	move 	 $a0, $s0
	jal 	 sort_list
	add 	 $a0, $s0, $zero
	jal 	 compact
	addi 	 $s1, $s1, 4
	sw 	 $v0, 0($s1)
	addi 	 $s0, $s0, 8
	move 	 $a0, $s0
	jal 	 sort_list
	add 	 $a0, $s0, $zero
	jal 	 compact
	addi 	 $s1, $s1, 4
	sw 	 $v0, 0($s1)
	addi 	 $s0, $s0, 8
	move 	 $a0, $s0
	jal 	 sort_list
	add 	 $a0, $s0, $zero
	jal 	 compact
	addi 	 $s1, $s1, 4
	sw 	 $v0, 0($s1)
	addi 	 $s0, $s0, 8
	move 	 $a0, $s0
	jal 	 sort_list
	add 	 $a0, $s0, $zero
	jal 	 compact
	addi 	 $s1, $s1, 4
	sw 	 $v0, 0($s1)
	addi 	 $s0, $s0, 8
	move 	 $a0, $s0
	jal 	 sort_list
	add 	 $a0, $s0, $zero
	jal 	 compact
	addi 	 $s1, $s1, 4
	sw 	 $v0, 0($s1)

	la	$t0, state		# load state
	li	$t1, 30	
	sw	$t1, 0($t0)		# state goes back 0

	la	$a0, output
	li	$a1, 60
	jal	print_data_in_memory

	j	done_dispatch

#---------------------------------------------------------------
#	Things needed for sort
#---------------------------------------------------------------
insert_element_after:	
	# inserts the new element $a0 after $a1
	# if $a1 is 0, then we insert at the front of the list

	bne	$a1, $zero, iea_not_head # if a1 is null, we have to assign the head and tail

	lw	$t0, 0($a2) 		# $t0 = mylist->head
	sw	$t0, 8($a0)		# node->next = mylist->head;
	beqz	$t0, iea_after_head	# if ( mylist->head != NULL ) {
	sw	$a0, 4($t0)		#   mylist->head->prev = node;
		     			# }
iea_after_head:	
	sw	$a0, 0($a2)		# mylist->head = node;
	lw	$t0, 4($a2)		# $t0 = mylist->tail
	bnez	$t0, iea_done		# if ( mylist->tail == NULL ) {
	sw	$a0, 4($a2)		#   mylist->tail = node;
iea_done:	     			# }
	jr	$ra

iea_not_head:
	lw	$t1, 8($a1)		# $t1 = prev->next
	bne	$t1, $zero, iea_not_tail# if ( prev->next == NULL ) {
	sw	$a0, 4($a2)		#   mylist->tail = node;
	b	iea_end			# }
iea_not_tail:				# else {
	sw	$t1, 8($a0)		#   node->next = prev->next;
	sw	$a0, 4($t1)		#   node->next->prev = node;
		     			# }

iea_end:	
	sw	$a0, 8($a1)		# store the new pointer as the next of $a1
	sw	$a1, 4($a0)		# store the old pointer as prev of $a0
	jr	$ra			# return
	# END insert_element_after

#------------------------------------------------------
#  Remove Element
#------------------------------------------------------
remove_element:
	# removes the element at $a0 (list is in $a1)
	# if this element is the whole list, we have to empty the list
	lw	$t0, 0($a1)  	        # t0 = mylist->head
	lw	$t1, 4($a1)  	        # t1 = mylist->tail
	bne	$t0, $t1, re_not_empty_list

re_empty_list:
	sw	$zero, 0($a1)		# zero out the head ptr
	sw	$zero, 4($a1)		# zero out the tail ptr
	j	re_done

re_not_empty_list:
	lw	$t2, 4($a0)		# t2 = node->prev
	lw	$t3, 8($a0)		# t3 = node->next
	bne	$t2, $zero, re_not_first# if (node->prev == NULL) {

	sw	$t3, 0($a1)		# mylist->head = node->next;
	sw	$zero, 4($t3)		# node->next->prev = NULL;
	j	re_done

re_not_first: 
	bne	$t3, $zero, re_not_last# if (node->next == NULL) {
	sw	$t2, 4($a1)		# mylist->tail = node->prev;
	sw	$zero, 8($t2)		# node->prev->next = NULL;
	j	re_done
re_not_last:
	sw	$t3, 8($t2)		# node->prev->next = node->next;
	sw	$t2, 4($t3)		# node->next->prev = node->prev;

re_done:
	sw	$zero, 4($a0)		# zero out $a0's prev
	sw	$zero, 8($a0)		# zero out $a0's next
	jr	$ra			# return
	# END remove_element
	
#--------------------------------------------------------------------------
#  Sort
#--------------------------------------------------------------------------
sort_list:  # $a0 = mylist
	lw	$t0, 0($a0)  	        # t0 = mylist->head, smallest
	lw	$t1, 4($a0)  	        # t1 = mylist->tail
	bne	$t0, $t1, sl_2_or_more	# if (mylist->head == mylist->tail) {
	jr	$ra  	  		#    return;

sl_2_or_more:
	sub	$sp, $sp, 12
	sw	$ra, 0($sp)		# save $ra
	sw	$a0, 4($sp)		# save my_list
	lw	$t1, 8($t0)  	        # t1 = trav = smallest->next
sl_loop:
	beq	$t1, $zero, sl_loop_done # trav != NULL
	lw	$t3, 0($t1) 		# trav->data
	lw	$t2, 0($t0) 		# smallest->data
	bge	$t3, $t2, sl_skip	# inverse of: if (trav->data < smallest->data) { 
	move	$t0, $t1		# smallest = trav;
sl_skip:
	lw	$t1, 8($t1)		# trav = trav->next
	j	sl_loop
	
sl_loop_done:
	sw	$t0, 8($sp)		# save smallest

	move	$a1, $a0		# my_list is arg2
	move 	$a0, $t0		# smallest is arg1
	jal 	remove_element		# remove_node(smallest, mylist);

	lw	$a0, 4($sp)		# restore my_list as arg1
	jal	sort_list		# sort_list(mylist);

	lw	$a0, 8($sp)		# restore smallest as arg1
	li	$a1, 0			# pass NULL as arg2
	lw	$a2, 4($sp)		# restore my_list as arg3
	jal	insert_element_after	# insert_node_after(smallest, NULL, mylist);

	lw	$ra, 0($sp)		# restore $ra
	add	$sp, $sp, 12	# this maybe needs to be 16 with new struct
	jr	$ra
	# END sort_list
#--------------------------------------------
#	Compact function args(list head, length, base_address of final array)
#--------------------------------------------
compact:
	sub	$sp, $sp, 4
	sw	$ra, 0($sp)
	addi	$v0, $zero, 0
  	li   	$t1, 0x80000000  	# $t1 = mask, initialized to 1 << 31
	lw	$t2, 0($a0)		# $t2 = list->head
compact_while:
	beq	$t2, $zero, return_compact 	# head == zero
	lw	$t3, 12($t2)		# $t3 = head->value
	beq	$t3, $zero, compact_value_zero	# if(value == zero)
	or	$v0, $v0, $t1		#val |= mask
	j	skip_compact_branch
compact_value_zero:
	not	$t0, $t1		# $t0 = ~mask
	and	$v0, $v0, $t0		# val &= ~mask
skip_compact_branch:
  	srl  	$t1, $t1, 1      	# mask = mask >> 1
	lw	$t2, 8($t2)		# $t2 = head->next
	j	compact_while
return_compact:
	lw	$ra, 0($sp)
	add	$sp, $sp, 4
	jr	$ra


# ----------------------------------------------------------
# This is the end of the sort and extract function
# ----------------------------------------------------------




# ----------------------------------------------------------------
# Arctan function - Part of the Euclidean Library
# Labels used include:
#
# ----------------------------------------------------------------
sb_arctan:
	li	$v0, 0		# angle = 0;

	abs	$t0, $a0	# get absolute values
	abs	$t1, $a1
	ble	$t1, $t0, no_TURN_90	  

	## if (abs(y) > abs(x)) { rotate 90 degrees }
	move	$t0, $a1	# int temp = y;
	sub	$a1, $zero, $a0	# y = -x;      
	move	$a0, $t0	# x = temp;    
	li	$v0, 90		# angle = 90;  

no_TURN_90:
	bge	$a0, $zero, pos_x 	# skip if (x >= 0)

	## if (x < 0) 
	add	$v0, $v0, 180	# angle += 180;

pos_x:
	mtc1	$a0, $f0
	mtc1	$a1, $f1
	cvt.s.w $f0, $f0	# convert from ints to floats
	cvt.s.w $f1, $f1
	
	div.s	$f0, $f1, $f0	# float v = (float) y / (float) x;

	mul.s	$f1, $f0, $f0	# v^^2
	mul.s	$f2, $f1, $f0	# v^^3
	l.s	$f3, three($zero)	# load 5.0
	div.s 	$f3, $f2, $f3	# v^^3/3
	sub.s	$f6, $f0, $f3	# v - v^^3/3

	mul.s	$f4, $f1, $f2	# v^^5
	l.s	$f5, five($zero)	# load 3.0
	div.s 	$f5, $f4, $f5	# v^^5/5
	add.s	$f6, $f6, $f5	# value = v - v^^3/3 + v^^5/5

	l.s	$f8, PI($zero)		# load PI
	div.s	$f6, $f6, $f8	# value / PI
	l.s	$f7, F180($zero)	# load 180.0
	mul.s	$f6, $f6, $f7	# 180.0 * value / PI

	cvt.w.s $f6, $f6	# convert "delta" back to integer
	mfc1	$t0, $f6
	add	$v0, $v0, $t0	# angle += delta

	jr 	$ra

# ----------------------------------------------------------
# This next section is dedicated to the functions that belong to the debug environment
# Author: John McConnell
# The labels used in this section include
# ----------------------------------------------------------

# Print the data of a memory address $a0 = @ of the data, $a1 = size of the data in bytes
# the function will step by 4 printing data from the memory address until it has stepped $a1 / 4 times
print_data_in_memory:
	sub	$sp, $sp, 16
	sw	$a0, 0($sp)
	sw	$t0, 4($sp)
	sw	$t1, 8($sp)
	sw	$v0, 12($sp)
	
	add	$t0, $a0, $a1	# address + offset in bytes
	sub	$t0, $t0, 4	# subtract 4 because load is 4 offset
	move	$t1, $a0	# t1 becomes current @

	li	$v0, 4
	la	$a0, data_memory_print_str
	syscall

print_data_memory_loop:
	bgt	$t1, $t0, done_printing_data

	li	$v0, 1		# print variable
	lw	$a0, 0($t1)
	syscall

	li	$v0, 4
	la	$a0, main_comma
	syscall

	addi	$t1, $t1, 4	
	j	print_data_memory_loop
done_printing_data:
	li	$v0, 4
	la	$a0, main_newline
	syscall

	lw	$a0, 0($sp)
	lw	$t0, 4($sp)
	lw	$t1, 8($sp)
	lw	$v0, 12($sp)
	addi	$sp, $sp, 16
	jr	$ra

# ALL your code goes below this line.
#
# We will delete EVERYTHING above the line; DO NOT delete the line.
#
# ---------------------------------------------------------------------

initialize:
     	li	$t4, 0xb001               	# Or(timer, bonk, scan, global)

     	mtc0   	$t4, $12                   	# set interrupt mask (Status register)
     
      	li      $t0, 0x96		       	# this is performing a scan
      	sw      $t0, 0xffff0050($zero)
      	sw      $t0, 0xffff0054($zero)
      	li      $t0, 0xd4
      	sw      $t0, 0xffff0058($zero)
      	la      $t0, scan_data
     	sw      $t0, 0xffff005c($zero)  

	jr	$ra

.kdata                 # interrupt handler data (separated just for readability)
chunkIH:.space 64      # space for 16 registers

#-----------------------------------------------------------
# This section is dedicated for strings to be printed by syscall
# the labels used are defined below
space:			.asciiz	" "
newline:	  	.asciiz "\n"
begin_str:		.asciiz "beginning task\n"
done_str:	  	.asciiz "done with task\n"
print_reg_v0_str:	.asciiz "Printing register v0: "
print_reg_v1_str:	.asciiz "Printing register v1: "
print_reg_a0_str:	.asciiz "Printing register a0: "
print_reg_a1_str:	.asciiz "Printing register a1: "
print_reg_a2_str:	.asciiz "Printing register a2: "
print_reg_a3_str:	.asciiz "Printing register a3: "
print_reg_t0_str:	.asciiz "Printing register t0: "
print_reg_t1_str:	.asciiz "Printing register t1: "
print_reg_t2_str:	.asciiz "Printing register t2: "
print_reg_t3_str:	.asciiz "Printing register t3: "
print_reg_t4_str:	.asciiz "Printing register t4: "
print_reg_t5_str:	.asciiz "Printing register t5: "
print_reg_t6_str:	.asciiz "Printing register t6: "
print_reg_t7_str:	.asciiz "Printing register t7: "
print_reg_t8_str:	.asciiz "Printing register t8: "
print_reg_t9_str:	.asciiz "Printing register t9: "
print_reg_s0_str:	.asciiz "Printing register s0: "
print_reg_s1_str:	.asciiz "Printing register s1: "
print_reg_s2_str:	.asciiz "Printing register s2: "
print_reg_s3_str:	.asciiz "Printing register s3: "
print_reg_s4_str:	.asciiz "Printing register s4: "
print_reg_s5_str:	.asciiz "Printing register s5: "
print_reg_s6_str: 	.asciiz "Printing register s6: "
print_reg_s7_str:	.asciiz "Printing register s7: "
print_reg_gp_str:	.asciiz "Printing global pointer register: "
print_reg_sp_str:	.asciiz "Printing stack pointer register: "
print_reg_fp_str:	.asciiz "Printing frame pointer register: "
print_reg_ra_str:	.asciiz "Printing return address pointe: "
timer_intrpt_str: 	.asciiz "time interrupt exception\n"
scanner_intrpt_str:	.asciiz "scanner interrupt exception\n"
bonk_intrpt_str:	.asciiz "bonk interrupt exception\n"
non_intrpt_str:   	.asciiz "Non-interrupt exception\n"
unhandled_str:    	.asciiz "Unhandled interrupt type\n"
# End of string sections
#----------------------------------------------------------


.ktext 0x80000180
interrupt_handler:
.set noat
      	move	$k1, $at               		# Save $at                               
.set at
      	la     	$k0, chunkIH                
      	sw	$a0, 0($k0)             	# Get some free registers                  
      	sw     	$a1, 4($k0)             	# by storing them to a global variable    
      	sw    	$t0, 8($k0)	       	
      	sw	$t1, 12($k0)		
	sw	$t2, 16($k0)		
	sw	$t3, 20($k0)		
	sw	$t4, 24($k0)
	sw	$t5, 28($k0)
	sw	$s0, 32($k0)
	sw	$s1, 36($k0)
	sw	$s2, 40($k0)
	sw	$s3, 44($k0)
	sw	$s4, 48($k0)
	sw	$s5, 52($k0)
	sw	$v0, 56($k0)
	sw	$sp, 60($k0)

      	mfc0    $s0, $13                 	# Get Cause register                       
      	srl     $t0, $s0, 2                
      	and     $t0, $t0, 0xf            	# ExcCode field                            
      	bne     $t0, 0, non_intrpt         

interrupt_dispatch:                    		# Interrupt:                             
      	mfc0    $s0, $13                 	# Get Cause register, again                 
      	beq     $s0, $zero, done         	# handled all outstanding interrupts    

      				       		# add dispatch for other interrupt types here.
  
      	and     $t0, $s0, 0x1000         	# is there a bonk interrupt?                
      	bne     $t0, 0, bonk_interrupt   

      	and     $t0, $s0, 0x2000	       	# is there a scanner interrupt?
      	bne     $t0, 0, scanner_interrupt

     	and     $t0, $s0, 0x8000         	# is there a timer interrupt?
      	bne     $t0, 0, timer_interrupt


      	li      $v0, 4                   	# Unhandled interrupt types $t1 = v0
      	la      $a0, unhandled_str
     	syscall 

      	j       done

bonk_interrupt:
      	sw      $t0, 0xffff0060($zero)   	# acknowledge interrupt

      	li      $v0, 4
      	la      $a0, bonk_intrpt_str
      	syscall			       		# print interrupt handler

	sub	$sp, $sp, 4
	sw	$ra, 0($sp)      

      	jal     bounce	       			# sort and extract

	lw	$ra, 0($sp)
	add	$sp, $sp, 4

	la	$v0, state			# make state equal 32
	li	$t0, 30
	sw	$t0, state

      	j       interrupt_dispatch       	# see if other interrupts are waiting

timer_interrupt:
      	sw      $t0, 0xffff006c($zero)  	# acknowledge interrupt

      	li      $v0, 4
      	la      $a0, timer_intrpt_str
      	syscall			       		# print interrupt handler

                                       		# REQUEST TIMER INTERRUPT
     	# lw     	$v0, 0xffff001c($0)        	# read current time
     	# add    	$v0, $v0, 1000000	       	# add 100 to current time
     	# sw     	$v0, 0xffff001c($0)        	# request timer interrupt in 100000 cycles

	# la	$v0, state
	# li	$t0, 32
	# sw	$t0, state

	j      	interrupt_dispatch	# see if other interrupts are waiting

scanner_interrupt:
      	sw      $a1, 0xffff0064($zero)   # acknowledge interrupt
      
      	li      $v0, 4
      	la      $a0, scanner_intrpt_str
      	syscall			       	# print interrupt handler 

	la	$t0, state		# make state == 32
	li	$t1, 32
	sw	$t1, 0($t0)

      	j	interrupt_dispatch
non_intrpt:                            	# was some non-interrupt

      	li      $v0, 4
      	la      $a0, non_intrpt_str
      	syscall                         # print out an error message

      # fall through to done

done:
      	la      $k0, chunkIH
      	lw	$a0, 0($k0)             # Restore Saved Registers                  
      	lw     	$a1, 4($k0)                 
      	lw    	$t0, 8($k0)	       	
      	lw	$t1, 12($k0)		
	lw	$t2, 16($k0)		
	lw	$t3, 20($k0)		
	lw	$t4, 24($k0)
	lw	$t5, 28($k0)
	lw	$s0, 32($k0)
	lw	$s1, 36($k0)
	lw	$s2, 40($k0)
	lw	$s3, 44($k0)
	lw	$s4, 48($k0)
	lw	$s5, 52($k0)
	lw	$v0, 56($k0)
	lw	$sp, 60($k0)
     	mfc0    $k0, $14                 # Exception Program Counter (PC)
.set noat
      	move    $at, $k1                 # Restore $at
.set at 
      	rfe   
      	jr      $k0
      	nop

print_output:
	sw	$ra, 24($k0)

	la 	$t0, output
	lw 	$t3, 0($t0)
	jal 	print_register_t3
	la 	$t0, output
	lw 	$t3, 4($t0)
	jal 	print_register_t3
	la 	$t0, output
	lw 	$t3, 8($t0)
	jal 	print_register_t3
	la 	$t0, output
	lw 	$t3, 12($t0)
	jal 	print_register_t3
	la 	$t0, output
	lw 	$t3, 16($t0)
	jal 	print_register_t3
	la 	$t0, output
	lw 	$t3, 20($t0)
	jal 	print_register_t3
	la 	$t0, output
	lw 	$t3, 24($t0)
	jal 	print_register_t3
	la 	$t0, output
	lw 	$t3, 28($t0)
	jal 	print_register_t3
	la 	$t0, output
	lw 	$t3, 32($t0)
	jal 	print_register_t3
	la 	$t0, output
	lw 	$t3, 36($t0)
	jal 	print_register_t3
	la 	$t0, output
	lw 	$t3, 40($t0)
	jal 	print_register_t3
	la 	$t0, output
	lw 	$t3, 44($t0)
	jal 	print_register_t3
	la 	$t0, output
	lw 	$t3, 48($t0)
	jal 	print_register_t3
	la 	$t0, output
	lw 	$t3, 52($t0)
	jal 	print_register_t3
	la 	$t0, output
	lw 	$t3, 56($t0)
	jal 	print_register_t3
	
	lw	$ra, 24($k0)
	jr	$ra

bounce:
	sub     $sp, $sp, 4
      	sw      $v0, 0($sp)
	
	lw	$v0, 0xffff0014($zero)
	addi	$v0, $v0, 90
	sw     	$v0, 0xffff0014($zero)  #set angle to new_angle
	
	li     	$t4, 0 
	sw     	$t4, 0xffff0018($zero)	#set orientation control = 1 (absolute)

	li     	$t4, 10	
	sw     	$t4, 0xffff0010($zero)	#set velocity to 10

	lw     	$v0, 0($sp)
	add	$sp, $sp, 4
	
	jr      $ra

	

# ----------------------------------------------------------
# This next section is dedicated to the functions that belong to the debug environment
# Author: John McConnell
# The labels used in this section include
#	print_all_registers
#	print_register
#	print_register_v1
#	print_register_a1
#	print_register_a2
#	print_register_a3
#	print_register_t0
#	print_register_t1
#	print_register_t2
#	print_register_t3
#	print_register_t4
#	print_register_t5
#	print_register_t6
#	print_register_t7
#	print_register_t8
#	print_register_t9
#	print_register_s0
#	print_register_s1
#	print_register_s2
#	print_register_s3
#	print_register_s4
#	print_register_s5
#	print_register_s6
#	print_register_s7
# ----------------------------------------------------------	
print_all_registers:
	sub	$sp, $sp, 4
	sw	$ra, 0($sp)
	jal	print_register_v0
	jal 	print_register_v1
	jal	print_register_a0
	jal	print_register_a1
	jal	print_register_a2
	jal	print_register_a3
	jal	print_register_t0
	jal	print_register_t1
	jal	print_register_t2
	jal	print_register_t3
	jal	print_register_t4
	jal	print_register_t5
	jal	print_register_t6
	jal	print_register_t7
	jal	print_register_t8
	jal	print_register_t9
	jal	print_register_s0
	jal	print_register_s1
	jal	print_register_s2
	jal	print_register_s3
	jal	print_register_s4
	jal	print_register_s5
	jal	print_register_s6
	jal	print_register_s7
	lw	$ra, 0($sp)
	add	$sp, $sp, 4
	jr	$ra

print_register:
      	li      $v0, 1		# Printer register as int
      	syscall			# Prints value in $a0

      	li      $v0, 4
      	la      $a0, newline	# Print a new line
	syscall
	jr	$ra

print_register_a0:
	sub 	$sp, $sp, 12 	 # save $a0 and $v0 on stack
	sw 	$ra, 0($sp)
	sw 	$v0, 4($sp)
	sw 	$a0, 8($sp)

	li 	$v0, 4
	la 	$a0, print_reg_a0_str
	syscall
	lw 	$a0, 8($sp)
	jal 	print_register

	lw 	$ra, 0($sp)
	lw 	$v0, 4($sp)
	lw 	$a0, 8($sp)
	add 	$sp, $sp, 12
	jr 	$ra
print_register_a1:
	sub 	$sp, $sp, 12 	 # save $a0 and $v0 on stack
	sw 	$ra, 0($sp)
	sw 	$v0, 4($sp)
	sw 	$a0, 8($sp)

	li 	$v0, 4
	la 	$a0, print_reg_a1_str
	syscall
	move 	$a0, $a1
	jal 	print_register

	lw 	$ra, 0($sp)
	lw 	$v0, 4($sp)
	lw 	$a0, 8($sp)
	add 	$sp, $sp, 12
	jr 	$ra
print_register_a2:
	sub 	$sp, $sp, 12 	 # save $a0 and $v0 on stack
	sw 	$ra, 0($sp)
	sw 	$v0, 4($sp)
	sw 	$a0, 8($sp)

	li 	$v0, 4
	la 	$a0, print_reg_a2_str
	syscall
	move 	$a0, $a2
	jal 	print_register

	lw 	$ra, 0($sp)
	lw 	$v0, 4($sp)
	lw 	$a0, 8($sp)
	add 	$sp, $sp, 12
	jr 	$ra
print_register_a3:
	sub 	$sp, $sp, 12 	 # save $a0 and $v0 on stack
	sw 	$ra, 0($sp)
	sw 	$v0, 4($sp)
	sw 	$a0, 8($sp)

	li 	$v0, 4
	la 	$a0, print_reg_a3_str
	syscall
	move 	$a0, $a3
	jal 	print_register

	lw 	$ra, 0($sp)
	lw 	$v0, 4($sp)
	lw 	$a0, 8($sp)
	add 	$sp, $sp, 12
	jr 	$ra
print_register_t0:
	sub 	$sp, $sp, 12 	 # save $a0 and $v0 on stack
	sw 	$ra, 0($sp)
	sw 	$v0, 4($sp)
	sw 	$a0, 8($sp)

	li 	$v0, 4
	la 	$a0, print_reg_t0_str
	syscall
	move 	$a0, $t0
	jal 	print_register

	lw 	$ra, 0($sp)
	lw 	$v0, 4($sp)
	lw 	$a0, 8($sp)
	add 	$sp, $sp, 12
	jr 	$ra
print_register_t1:
	sub 	$sp, $sp, 12 	 # save $a0 and $v0 on stack
	sw 	$ra, 0($sp)
	sw 	$v0, 4($sp)
	sw 	$a0, 8($sp)

	li 	$v0, 4
	la 	$a0, print_reg_t1_str
	syscall
	move 	$a0, $t1
	jal 	print_register

	lw 	$ra, 0($sp)
	lw 	$v0, 4($sp)
	lw 	$a0, 8($sp)
	add 	$sp, $sp, 12
	jr 	$ra
print_register_t2:
	sub 	$sp, $sp, 12 	 # save $a0 and $v0 on stack
	sw 	$ra, 0($sp)
	sw 	$v0, 4($sp)
	sw 	$a0, 8($sp)

	li 	$v0, 4
	la 	$a0, print_reg_t2_str
	syscall
	move 	$a0, $t2
	jal 	print_register

	lw 	$ra, 0($sp)
	lw 	$v0, 4($sp)
	lw 	$a0, 8($sp)
	add 	$sp, $sp, 12
	jr 	$ra
print_register_t3:
	sub 	$sp, $sp, 12 	 # save $a0 and $v0 on stack
	sw 	$ra, 0($sp)
	sw 	$v0, 4($sp)
	sw 	$a0, 8($sp)

	li 	$v0, 4
	la 	$a0, print_reg_t3_str
	syscall
	move 	$a0, $t3
	jal 	print_register

	lw 	$ra, 0($sp)
	lw 	$v0, 4($sp)
	lw 	$a0, 8($sp)
	add 	$sp, $sp, 12
	jr 	$ra
print_register_t4:
	sub 	$sp, $sp, 12 	 # save $a0 and $v0 on stack
	sw 	$ra, 0($sp)
	sw 	$v0, 4($sp)
	sw 	$a0, 8($sp)

	li 	$v0, 4
	la 	$a0, print_reg_t4_str
	syscall
	move 	$a0, $t4
	jal 	print_register

	lw 	$ra, 0($sp)
	lw 	$v0, 4($sp)
	lw 	$a0, 8($sp)
	add 	$sp, $sp, 12
	jr 	$ra
print_register_t5:
	sub 	$sp, $sp, 12 	 # save $a0 and $v0 on stack
	sw 	$ra, 0($sp)
	sw 	$v0, 4($sp)
	sw 	$a0, 8($sp)

	li 	$v0, 4
	la 	$a0, print_reg_t5_str
	syscall
	move 	$a0, $t5
	jal 	print_register

	lw 	$ra, 0($sp)
	lw 	$v0, 4($sp)
	lw 	$a0, 8($sp)
	add 	$sp, $sp, 12
	jr 	$ra
print_register_t6:
	sub 	$sp, $sp, 12 	 # save $a0 and $v0 on stack
	sw 	$ra, 0($sp)
	sw 	$v0, 4($sp)
	sw 	$a0, 8($sp)

	li 	$v0, 4
	la 	$a0, print_reg_t6_str
	syscall
	move 	$a0, $t6
	jal 	print_register

	lw 	$ra, 0($sp)
	lw 	$v0, 4($sp)
	lw 	$a0, 8($sp)
	add 	$sp, $sp, 12
	jr 	$ra
print_register_t7:
	sub 	$sp, $sp, 12 	 # save $a0 and $v0 on stack
	sw 	$ra, 0($sp)
	sw 	$v0, 4($sp)
	sw 	$a0, 8($sp)

	li 	$v0, 4
	la 	$a0, print_reg_t7_str
	syscall
	move 	$a0, $t7
	jal 	print_register

	lw 	$ra, 0($sp)
	lw 	$v0, 4($sp)
	lw 	$a0, 8($sp)
	add 	$sp, $sp, 12
	jr 	$ra
print_register_t8:
	sub 	$sp, $sp, 12 	 # save $a0 and $v0 on stack
	sw 	$ra, 0($sp)
	sw 	$v0, 4($sp)
	sw 	$a0, 8($sp)

	li 	$v0, 4
	la 	$a0, print_reg_t8_str
	syscall
	move 	$a0, $t8
	jal 	print_register

	lw 	$ra, 0($sp)
	lw 	$v0, 4($sp)
	lw 	$a0, 8($sp)
	add 	$sp, $sp, 12
	jr 	$ra
print_register_t9:
	sub 	$sp, $sp, 12 	 # save $a0 and $v0 on stack
	sw 	$ra, 0($sp)
	sw 	$v0, 4($sp)
	sw 	$a0, 8($sp)

	li 	$v0, 4
	la 	$a0, print_reg_t9_str
	syscall
	move 	$a0, $t9
	jal 	print_register

	lw 	$ra, 0($sp)
	lw 	$v0, 4($sp)
	lw 	$a0, 8($sp)
	add 	$sp, $sp, 12
	jr 	$ra
print_register_s0:
	sub 	$sp, $sp, 12 	 # save $a0 and $v0 on stack
	sw 	$ra, 0($sp)
	sw 	$v0, 4($sp)
	sw 	$a0, 8($sp)

	li 	$v0, 4
	la 	$a0, print_reg_s0_str
	syscall
	move 	$a0, $s0
	jal 	print_register

	lw 	$ra, 0($sp)
	lw 	$v0, 4($sp)
	lw 	$a0, 8($sp)
	add 	$sp, $sp, 12
	jr 	$ra
print_register_s1:
	sub 	$sp, $sp, 12 	 # save $a0 and $v0 on stack
	sw 	$ra, 0($sp)
	sw 	$v0, 4($sp)
	sw 	$a0, 8($sp)

	li 	$v0, 4
	la 	$a0, print_reg_s1_str
	syscall
	move 	$a0, $s1
	jal 	print_register

	lw 	$ra, 0($sp)
	lw 	$v0, 4($sp)
	lw 	$a0, 8($sp)
	add 	$sp, $sp, 12
	jr 	$ra
print_register_s2:
	sub 	$sp, $sp, 12 	 # save $a0 and $v0 on stack
	sw 	$ra, 0($sp)
	sw 	$v0, 4($sp)
	sw 	$a0, 8($sp)

	li 	$v0, 4
	la 	$a0, print_reg_s2_str
	syscall
	move 	$a0, $s2
	jal 	print_register

	lw 	$ra, 0($sp)
	lw 	$v0, 4($sp)
	lw 	$a0, 8($sp)
	add 	$sp, $sp, 12
	jr 	$ra
print_register_s3:
	sub 	$sp, $sp, 12 	 # save $a0 and $v0 on stack
	sw 	$ra, 0($sp)
	sw 	$v0, 4($sp)
	sw 	$a0, 8($sp)

	li 	$v0, 4
	la 	$a0, print_reg_s3_str
	syscall
	move 	$a0, $s3
	jal 	print_register

	lw 	$ra, 0($sp)
	lw 	$v0, 4($sp)
	lw 	$a0, 8($sp)
	add 	$sp, $sp, 12
	jr 	$ra
print_register_s4:
	sub 	$sp, $sp, 12 	 # save $a0 and $v0 on stack
	sw 	$ra, 0($sp)
	sw 	$v0, 4($sp)
	sw 	$a0, 8($sp)

	li 	$v0, 4
	la 	$a0, print_reg_s4_str
	syscall
	move 	$a0, $s4
	jal 	print_register

	lw 	$ra, 0($sp)
	lw 	$v0, 4($sp)
	lw 	$a0, 8($sp)
	add 	$sp, $sp, 12
	jr 	$ra
print_register_s5:
	sub 	$sp, $sp, 12 	 # save $a0 and $v0 on stack
	sw 	$ra, 0($sp)
	sw 	$v0, 4($sp)
	sw 	$a0, 8($sp)

	li 	$v0, 4
	la 	$a0, print_reg_s5_str
	syscall
	move 	$a0, $s5
	jal 	print_register

	lw 	$ra, 0($sp)
	lw 	$v0, 4($sp)
	lw 	$a0, 8($sp)
	add 	$sp, $sp, 12
	jr 	$ra
print_register_s6:
	sub 	$sp, $sp, 12 	 # save $a0 and $v0 on stack
	sw 	$ra, 0($sp)
	sw 	$v0, 4($sp)
	sw 	$a0, 8($sp)

	li 	$v0, 4
	la 	$a0, print_reg_s6_str
	syscall
	move 	$a0, $s6
	jal 	print_register

	lw 	$ra, 0($sp)
	lw 	$v0, 4($sp)
	lw 	$a0, 8($sp)
	add 	$sp, $sp, 12
	jr 	$ra
print_register_s7:
	sub 	$sp, $sp, 12 	 # save $a0 and $v0 on stack
	sw 	$ra, 0($sp)
	sw 	$v0, 4($sp)
	sw 	$a0, 8($sp)

	li 	$v0, 4
	la 	$a0, print_reg_s7_str
	syscall
	move 	$a0, $s7
	jal 	print_register

	lw 	$ra, 0($sp)
	lw 	$v0, 4($sp)
	lw 	$a0, 8($sp)
	add 	$sp, $sp, 12
	jr 	$ra
print_register_v0:
	sub 	$sp, $sp, 12 	 # save $a0 and $v0 on stack
	sw 	$ra, 0($sp)
	sw 	$v0, 4($sp)
	sw 	$a0, 8($sp)

	li 	$v0, 4
	la 	$a0, print_reg_v0_str
	syscall
	lw 	$a0, 4($sp)
	jal 	print_register

	lw 	$ra, 0($sp)
	lw 	$v0, 4($sp)
	lw 	$a0, 8($sp)
	add 	$sp, $sp, 12
	jr 	$ra
print_register_v1:
	sub 	$sp, $sp, 12 	 # save $a0 and $v0 on stack
	sw 	$ra, 0($sp)
	sw 	$v0, 4($sp)
	sw 	$a0, 8($sp)

	li 	$v0, 4
	la 	$a0, print_reg_v1_str
	syscall
	move 	$a0, $v1
	jal 	print_register

	lw 	$ra, 0($sp)
	lw 	$v0, 4($sp)
	lw 	$a0, 8($sp)
	add 	$sp, $sp, 12
	jr 	$ra


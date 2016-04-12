        j exit
L1:	addi $s0, $zero ,42
l1:	add $s1, $zero, $0
	bne $s1 , $0 l1
	beq $s1 $0 L1
hang:	j hang
exit:

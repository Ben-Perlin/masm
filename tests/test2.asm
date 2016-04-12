start:	addi $s0, $zero, 42
	andi $s1, $zero, 42
	ori $s3, $zero, 42

        beq $s0, $zero, crash
        bne $s0, $s1, burn
	bne $s0, $s2, crash
	sw $s0, 0($s0)
	lw $s3, 0($s0)
        bne $s0, $s3, burn

	jal pool_on_the_roof

	add $t0, $zero, $s1
	and $t0, $t0, $s0
	or $t0, $t0, $s0
	sll $t0, $t0, 5
	srl $t0, $t0, 5
	sub $t0, $t0, $s1
	bne $t0, $zero, crash
	
	# looks like the pool on the roof sprung a leak

        nor $t0, $zero, $zero
	slt $t0, $t0, $zero
	beq $t0, $zero, burn
	
	j exit

pool_on_the_roof:	jr $ra

crash:  j burn
burn:	j crash

exit:

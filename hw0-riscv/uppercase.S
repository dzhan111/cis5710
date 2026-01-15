        .section .data
input_string:   .asciz "Hello beans!"

        # tohost/fromhost are data locations used by Spike
        .align 8
tohost: .byte 0
        .align 8
fromhost: .byte 0

        
        .section .text
        .globl _start
_start:
        # Load the address of the input string into a0
        la a0, input_string

        # Your code here!
        loop:
                lbu t1, 0(a0)
                # compare t1 to 0 --> exit 
                beq t1, x0, end_program 

                # make sure char is letter
                # chekc 'a' and 'z'
                li t2, 97
                blt t1, t2, skip
                li t2, 122
                bgt t1, t2, skip
                
                # convert to uppercase
                addi t1, t1, -32

                # WRITE BACK INTO MEMORY FROM REGISTERS
                sb t1, 0(a0)

                skip:
                # inc index
                addi a0, a0, 1

                j loop

        
end_program:
        # jump here when you're done
        j end_program


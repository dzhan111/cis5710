
uppercase.bin:     file format elf32-littleriscv


Disassembly of section .text:

00010074 <_start>:
   10074:	ffff2517          	auipc	a0,0xffff2
   10078:	f8c50513          	addi	a0,a0,-116 # 2000 <__DATA_BEGIN__>

0001007c <loop>:
   1007c:	00054303          	lbu	t1,0(a0)
   10080:	02030263          	beqz	t1,100a4 <end_program>
   10084:	06100393          	li	t2,97
   10088:	00734a63          	blt	t1,t2,1009c <skip>
   1008c:	07a00393          	li	t2,122
   10090:	0063c663          	blt	t2,t1,1009c <skip>
   10094:	fe030313          	addi	t1,t1,-32
   10098:	00650023          	sb	t1,0(a0)

0001009c <skip>:
   1009c:	00150513          	addi	a0,a0,1
   100a0:	fddff06f          	j	1007c <loop>

000100a4 <end_program>:
   100a4:	0000006f          	j	100a4 <end_program>

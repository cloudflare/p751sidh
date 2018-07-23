// +build amd64,!noasm

#include "textflag.h"

// p751 + 1
#define P751P1_5   $0xEEB0000000000000
#define P751P1_6   $0xE3EC968549F878A8
#define P751P1_7   $0xDA959B1A13F7CC76
#define P751P1_8   $0x084E9867D6EBE876
#define P751P1_9   $0x8562B5045CB25748
#define P751P1_10  $0x0E12909F97BADC66
#define P751P1_11  $0x00006FE5D541F71C

#define P751_0     $0xFFFFFFFFFFFFFFFF
#define P751_5     $0xEEAFFFFFFFFFFFFF
#define P751_6     $0xE3EC968549F878A8
#define P751_7     $0xDA959B1A13F7CC76
#define P751_8     $0x084E9867D6EBE876
#define P751_9     $0x8562B5045CB25748
#define P751_10    $0x0E12909F97BADC66
#define P751_11    $0x00006FE5D541F71C

#define P751X2_0   $0xFFFFFFFFFFFFFFFE
#define P751X2_1   $0xFFFFFFFFFFFFFFFF
#define P751X2_5   $0xDD5FFFFFFFFFFFFF
#define P751X2_6   $0xC7D92D0A93F0F151
#define P751X2_7   $0xB52B363427EF98ED
#define P751X2_8   $0x109D30CFADD7D0ED
#define P751X2_9   $0x0AC56A08B964AE90
#define P751X2_10  $0x1C25213F2F75B8CD
#define P751X2_11  $0x0000DFCBAA83EE38

// The MSR code uses these registers for parameter passing.  Keep using
// them to avoid significant code changes.  This means that when the Go
// assembler does something strange, we can diff the machine code
// against a different assembler to find out what Go did.

#define REG_P1 DI
#define REG_P2 SI
#define REG_P3 DX

// We can't write MOVQ $0, AX because Go's assembler incorrectly
// optimizes this to XOR AX, AX, which clobbers the carry flags.
//
// This bug was defined to be "correct" behaviour (cf.
// https://github.com/golang/go/issues/12405 ) by declaring that the MOV
// pseudo-instruction clobbers flags, although this fact is mentioned
// nowhere in the documentation for the Go assembler.
//
// Defining MOVQ to clobber flags has the effect that it is never safe
// to interleave MOVQ with ADCQ and SBBQ instructions.  Since this is
// required to write a carry chain longer than registers' working set,
// all of the below code therefore relies on the unspecified and
// undocumented behaviour that MOV won't clobber flags, except in the
// case of the above-mentioned bug.
//
// However, there's also no specification of which instructions
// correspond to machine instructions, and which are
// pseudo-instructions (i.e., no specification of what the assembler
// actually does), so this doesn't seem much worse than usual.
//
// Avoid the bug by dropping the bytes for `mov eax, 0` in directly:

#define ZERO_AX_WITHOUT_CLOBBERING_FLAGS BYTE	$0xB8; BYTE $0; BYTE $0; BYTE $0; BYTE $0;

TEXT ·fp751StrongReduce(SB), NOSPLIT, $0-8
	MOVQ	x+0(FP), REG_P1

	// Zero AX for later use:
	XORQ	AX, AX

	// Load p into registers:
	MOVQ	P751_0, R8
	// P751_{1,2,3,4} = P751_0, so reuse R8
	MOVQ	P751_5, R9
	MOVQ	P751_6, R10
	MOVQ	P751_7, R11
	MOVQ	P751_8, R12
	MOVQ	P751_9, R13
	MOVQ	P751_10, R14
	MOVQ	P751_11, R15

	// Set x <- x - p
	SUBQ	R8, (REG_P1)
	SBBQ	R8, (8)(REG_P1)
	SBBQ	R8, (16)(REG_P1)
	SBBQ	R8, (24)(REG_P1)
	SBBQ	R8, (32)(REG_P1)
	SBBQ	R9, (40)(REG_P1)
	SBBQ	R10, (48)(REG_P1)
	SBBQ	R11, (56)(REG_P1)
	SBBQ	R12, (64)(REG_P1)
	SBBQ	R13, (72)(REG_P1)
	SBBQ	R14, (80)(REG_P1)
	SBBQ    R15, (88)(REG_P1)

	// Save carry flag indicating x-p < 0 as a mask in AX
	SBBQ	$0, AX

	// Conditionally add p to x if x-p < 0
	ANDQ	AX, R8
	ANDQ	AX, R9
	ANDQ	AX, R10
	ANDQ	AX, R11
	ANDQ	AX, R12
	ANDQ	AX, R13
	ANDQ	AX, R14
	ANDQ	AX, R15

	ADDQ	R8, (REG_P1)
	ADCQ	R8, (8)(REG_P1)
	ADCQ	R8, (16)(REG_P1)
	ADCQ	R8, (24)(REG_P1)
	ADCQ	R8, (32)(REG_P1)
	ADCQ	R9, (40)(REG_P1)
	ADCQ	R10, (48)(REG_P1)
	ADCQ	R11, (56)(REG_P1)
	ADCQ	R12, (64)(REG_P1)
	ADCQ	R13, (72)(REG_P1)
	ADCQ	R14, (80)(REG_P1)
	ADCQ    R15, (88)(REG_P1)

	RET

TEXT ·fp751ConditionalSwap(SB), NOSPLIT, $0-17

	MOVQ	x+0(FP), REG_P1
	MOVQ	y+8(FP), REG_P2
	MOVB	choice+16(FP), AL	// AL = 0 or 1
	MOVBLZX	AL, AX			// AX = 0 or 1
	NEGQ	AX			// RAX = 0x00..00 or 0xff..ff

	MOVQ	(0*8)(REG_P1), BX	// BX = x[0]
	MOVQ 	(0*8)(REG_P2), CX	// CX = y[0]
	MOVQ	CX, DX			// DX = y[0]
	XORQ	BX, DX			// DX = y[0] ^ x[0]
	ANDQ	AX, DX			// DX = (y[0] ^ x[0]) & mask
	XORQ	DX, BX			// BX = (y[0] ^ x[0]) & mask) ^ x[0] = x[0] or y[0]
	XORQ	DX, CX			// CX = (y[0] ^ x[0]) & mask) ^ y[0] = y[0] or x[0]
	MOVQ	BX, (0*8)(REG_P1)
	MOVQ	CX, (0*8)(REG_P2)

	MOVQ	(1*8)(REG_P1), BX
	MOVQ 	(1*8)(REG_P2), CX
	MOVQ	CX, DX
	XORQ	BX, DX
	ANDQ	AX, DX
	XORQ	DX, BX
	XORQ	DX, CX
	MOVQ	BX, (1*8)(REG_P1)
	MOVQ	CX, (1*8)(REG_P2)

	MOVQ	(2*8)(REG_P1), BX
	MOVQ 	(2*8)(REG_P2), CX
	MOVQ	CX, DX
	XORQ	BX, DX
	ANDQ	AX, DX
	XORQ	DX, BX
	XORQ	DX, CX
	MOVQ	BX, (2*8)(REG_P1)
	MOVQ	CX, (2*8)(REG_P2)

	MOVQ	(3*8)(REG_P1), BX
	MOVQ 	(3*8)(REG_P2), CX
	MOVQ	CX, DX
	XORQ	BX, DX
	ANDQ	AX, DX
	XORQ	DX, BX
	XORQ	DX, CX
	MOVQ	BX, (3*8)(REG_P1)
	MOVQ	CX, (3*8)(REG_P2)

	MOVQ	(4*8)(REG_P1), BX
	MOVQ 	(4*8)(REG_P2), CX
	MOVQ	CX, DX
	XORQ	BX, DX
	ANDQ	AX, DX
	XORQ	DX, BX
	XORQ	DX, CX
	MOVQ	BX, (4*8)(REG_P1)
	MOVQ	CX, (4*8)(REG_P2)

	MOVQ	(5*8)(REG_P1), BX
	MOVQ 	(5*8)(REG_P2), CX
	MOVQ	CX, DX
	XORQ	BX, DX
	ANDQ	AX, DX
	XORQ	DX, BX
	XORQ	DX, CX
	MOVQ	BX, (5*8)(REG_P1)
	MOVQ	CX, (5*8)(REG_P2)

	MOVQ	(6*8)(REG_P1), BX
	MOVQ 	(6*8)(REG_P2), CX
	MOVQ	CX, DX
	XORQ	BX, DX
	ANDQ	AX, DX
	XORQ	DX, BX
	XORQ	DX, CX
	MOVQ	BX, (6*8)(REG_P1)
	MOVQ	CX, (6*8)(REG_P2)

	MOVQ	(7*8)(REG_P1), BX
	MOVQ 	(7*8)(REG_P2), CX
	MOVQ	CX, DX
	XORQ	BX, DX
	ANDQ	AX, DX
	XORQ	DX, BX
	XORQ	DX, CX
	MOVQ	BX, (7*8)(REG_P1)
	MOVQ	CX, (7*8)(REG_P2)

	MOVQ	(8*8)(REG_P1), BX
	MOVQ 	(8*8)(REG_P2), CX
	MOVQ	CX, DX
	XORQ	BX, DX
	ANDQ	AX, DX
	XORQ	DX, BX
	XORQ	DX, CX
	MOVQ	BX, (8*8)(REG_P1)
	MOVQ	CX, (8*8)(REG_P2)

	MOVQ	(9*8)(REG_P1), BX
	MOVQ 	(9*8)(REG_P2), CX
	MOVQ	CX, DX
	XORQ	BX, DX
	ANDQ	AX, DX
	XORQ	DX, BX
	XORQ	DX, CX
	MOVQ	BX, (9*8)(REG_P1)
	MOVQ	CX, (9*8)(REG_P2)

	MOVQ	(10*8)(REG_P1), BX
	MOVQ 	(10*8)(REG_P2), CX
	MOVQ	CX, DX
	XORQ	BX, DX
	ANDQ	AX, DX
	XORQ	DX, BX
	XORQ	DX, CX
	MOVQ	BX, (10*8)(REG_P1)
	MOVQ	CX, (10*8)(REG_P2)

	MOVQ	(11*8)(REG_P1), BX
	MOVQ 	(11*8)(REG_P2), CX
	MOVQ	CX, DX
	XORQ	BX, DX
	ANDQ	AX, DX
	XORQ	DX, BX
	XORQ	DX, CX
	MOVQ	BX, (11*8)(REG_P1)
	MOVQ	CX, (11*8)(REG_P2)

	RET

TEXT ·fp751AddReduced(SB), NOSPLIT, $0-24

	MOVQ	z+0(FP), REG_P3
	MOVQ	x+8(FP), REG_P1
	MOVQ	y+16(FP), REG_P2

	MOVQ	(REG_P1), R8
	MOVQ	(8)(REG_P1), R9
	MOVQ	(16)(REG_P1), R10
	MOVQ	(24)(REG_P1), R11
	MOVQ	(32)(REG_P1), R12
	MOVQ	(40)(REG_P1), R13
	MOVQ	(48)(REG_P1), R14
	MOVQ	(56)(REG_P1), R15
	MOVQ	(64)(REG_P1), CX
	ADDQ	(REG_P2), R8
	ADCQ	(8)(REG_P2), R9
	ADCQ	(16)(REG_P2), R10
	ADCQ	(24)(REG_P2), R11
	ADCQ	(32)(REG_P2), R12
	ADCQ	(40)(REG_P2), R13
	ADCQ	(48)(REG_P2), R14
	ADCQ	(56)(REG_P2), R15
	ADCQ	(64)(REG_P2), CX
	MOVQ	(72)(REG_P1), AX
	ADCQ	(72)(REG_P2), AX
	MOVQ	AX, (72)(REG_P3)
	MOVQ	(80)(REG_P1), AX
	ADCQ	(80)(REG_P2), AX
	MOVQ	AX, (80)(REG_P3)
	MOVQ	(88)(REG_P1), AX
	ADCQ	(88)(REG_P2), AX
	MOVQ	AX, (88)(REG_P3)

	MOVQ	P751X2_0, AX
	SUBQ	AX, R8
	MOVQ	P751X2_1, AX
	SBBQ	AX, R9
	SBBQ	AX, R10
	SBBQ	AX, R11
	SBBQ	AX, R12
	MOVQ	P751X2_5, AX
	SBBQ	AX, R13
	MOVQ	P751X2_6, AX
	SBBQ	AX, R14
	MOVQ	P751X2_7, AX
	SBBQ	AX, R15
	MOVQ	P751X2_8, AX
	SBBQ	AX, CX
	MOVQ	R8, (REG_P3)
	MOVQ	R9, (8)(REG_P3)
	MOVQ	R10, (16)(REG_P3)
	MOVQ	R11, (24)(REG_P3)
	MOVQ	R12, (32)(REG_P3)
	MOVQ	R13, (40)(REG_P3)
	MOVQ	R14, (48)(REG_P3)
	MOVQ	R15, (56)(REG_P3)
	MOVQ	CX, (64)(REG_P3)
	MOVQ	(72)(REG_P3), R8
	MOVQ	(80)(REG_P3), R9
	MOVQ	(88)(REG_P3), R10
	MOVQ	P751X2_9, AX
	SBBQ	AX, R8
	MOVQ	P751X2_10, AX
	SBBQ	AX, R9
	MOVQ	P751X2_11, AX
	SBBQ	AX, R10
	MOVQ	R8, (72)(REG_P3)
	MOVQ	R9, (80)(REG_P3)
	MOVQ	R10, (88)(REG_P3)
	ZERO_AX_WITHOUT_CLOBBERING_FLAGS
	SBBQ	$0, AX

	MOVQ	P751X2_0, SI
	ANDQ	AX, SI
	MOVQ	P751X2_1, R8
	ANDQ	AX, R8
	MOVQ	P751X2_5, R9
	ANDQ	AX, R9
	MOVQ	P751X2_6, R10
	ANDQ	AX, R10
	MOVQ	P751X2_7, R11
	ANDQ	AX, R11
	MOVQ	P751X2_8, R12
	ANDQ	AX, R12
	MOVQ	P751X2_9, R13
	ANDQ	AX, R13
	MOVQ	P751X2_10, R14
	ANDQ	AX, R14
	MOVQ	P751X2_11, R15
	ANDQ	AX, R15

	MOVQ	(REG_P3), AX
	ADDQ	SI, AX
	MOVQ	AX, (REG_P3)
	MOVQ	(8)(REG_P3), AX
	ADCQ	R8, AX
	MOVQ	AX, (8)(REG_P3)
	MOVQ	(16)(REG_P3), AX
	ADCQ	R8, AX
	MOVQ	AX, (16)(REG_P3)
	MOVQ	(24)(REG_P3), AX
	ADCQ	R8, AX
	MOVQ	AX, (24)(REG_P3)
	MOVQ	(32)(REG_P3), AX
	ADCQ	R8, AX
	MOVQ	AX, (32)(REG_P3)
	MOVQ	(40)(REG_P3), AX
	ADCQ	R9, AX
	MOVQ	AX, (40)(REG_P3)
	MOVQ	(48)(REG_P3), AX
	ADCQ	R10, AX
	MOVQ	AX, (48)(REG_P3)
	MOVQ	(56)(REG_P3), AX
	ADCQ	R11, AX
	MOVQ	AX, (56)(REG_P3)
	MOVQ	(64)(REG_P3), AX
	ADCQ	R12, AX
	MOVQ	AX, (64)(REG_P3)
	MOVQ	(72)(REG_P3), AX
	ADCQ	R13, AX
	MOVQ	AX, (72)(REG_P3)
	MOVQ	(80)(REG_P3), AX
	ADCQ	R14, AX
	MOVQ	AX, (80)(REG_P3)
	MOVQ	(88)(REG_P3), AX
	ADCQ	R15, AX
	MOVQ	AX, (88)(REG_P3)

	RET

TEXT ·fp751SubReduced(SB), NOSPLIT, $0-24

	MOVQ	z+0(FP),  REG_P3
	MOVQ	x+8(FP),  REG_P1
	MOVQ	y+16(FP),  REG_P2

	MOVQ	(REG_P1), R8
	MOVQ	(8)(REG_P1), R9
	MOVQ	(16)(REG_P1), R10
	MOVQ	(24)(REG_P1), R11
	MOVQ	(32)(REG_P1), R12
	MOVQ	(40)(REG_P1), R13
	MOVQ	(48)(REG_P1), R14
	MOVQ	(56)(REG_P1), R15
	MOVQ	(64)(REG_P1), CX
	SUBQ	(REG_P2), R8
	SBBQ	(8)(REG_P2), R9
	SBBQ	(16)(REG_P2), R10
	SBBQ	(24)(REG_P2), R11
	SBBQ	(32)(REG_P2), R12
	SBBQ	(40)(REG_P2), R13
	SBBQ	(48)(REG_P2), R14
	SBBQ	(56)(REG_P2), R15
	SBBQ	(64)(REG_P2), CX
	MOVQ	R8, (REG_P3)
	MOVQ	R9, (8)(REG_P3)
	MOVQ	R10, (16)(REG_P3)
	MOVQ	R11, (24)(REG_P3)
	MOVQ	R12, (32)(REG_P3)
	MOVQ	R13, (40)(REG_P3)
	MOVQ	R14, (48)(REG_P3)
	MOVQ	R15, (56)(REG_P3)
	MOVQ	CX, (64)(REG_P3)
	MOVQ	(72)(REG_P1), AX
	SBBQ	(72)(REG_P2), AX
	MOVQ	AX, (72)(REG_P3)
	MOVQ	(80)(REG_P1), AX
	SBBQ	(80)(REG_P2), AX
	MOVQ	AX, (80)(REG_P3)
	MOVQ	(88)(REG_P1), AX
	SBBQ	(88)(REG_P2), AX
	MOVQ	AX, (88)(REG_P3)
	ZERO_AX_WITHOUT_CLOBBERING_FLAGS
	SBBQ	$0, AX

	MOVQ	P751X2_0, SI
	ANDQ	AX, SI
	MOVQ	P751X2_1, R8
	ANDQ	AX, R8
	MOVQ	P751X2_5, R9
	ANDQ	AX, R9
	MOVQ	P751X2_6, R10
	ANDQ	AX, R10
	MOVQ	P751X2_7, R11
	ANDQ	AX, R11
	MOVQ	P751X2_8, R12
	ANDQ	AX, R12
	MOVQ	P751X2_9, R13
	ANDQ	AX, R13
	MOVQ	P751X2_10, R14
	ANDQ	AX, R14
	MOVQ	P751X2_11, R15
	ANDQ	AX, R15

	MOVQ	(REG_P3), AX
	ADDQ	SI, AX
	MOVQ	AX, (REG_P3)
	MOVQ	(8)(REG_P3), AX
	ADCQ	R8, AX
	MOVQ	AX, (8)(REG_P3)
	MOVQ	(16)(REG_P3), AX
	ADCQ	R8, AX
	MOVQ	AX, (16)(REG_P3)
	MOVQ	(24)(REG_P3), AX
	ADCQ	R8, AX
	MOVQ	AX, (24)(REG_P3)
	MOVQ	(32)(REG_P3), AX
	ADCQ	R8, AX
	MOVQ	AX, (32)(REG_P3)
	MOVQ	(40)(REG_P3), AX
	ADCQ	R9, AX
	MOVQ	AX, (40)(REG_P3)
	MOVQ	(48)(REG_P3), AX
	ADCQ	R10, AX
	MOVQ	AX, (48)(REG_P3)
	MOVQ	(56)(REG_P3), AX
	ADCQ	R11, AX
	MOVQ	AX, (56)(REG_P3)
	MOVQ	(64)(REG_P3), AX
	ADCQ	R12, AX
	MOVQ	AX, (64)(REG_P3)
	MOVQ	(72)(REG_P3), AX
	ADCQ	R13, AX
	MOVQ	AX, (72)(REG_P3)
	MOVQ	(80)(REG_P3), AX
	ADCQ	R14, AX
	MOVQ	AX, (80)(REG_P3)
	MOVQ	(88)(REG_P3), AX
	ADCQ	R15, AX
	MOVQ	AX, (88)(REG_P3)

	RET

TEXT ·fp751Mul(SB), $96-24

	// Here we store the destination in CX instead of in REG_P3 because the
	// multiplication instructions use DX as an implicit destination
	// operand: MULQ $REG sets DX:AX <-- AX * $REG.

	MOVQ	z+0(FP), CX
	MOVQ	x+8(FP), REG_P1
	MOVQ	y+16(FP), REG_P2

	XORQ	AX, AX
	MOVQ	(48)(REG_P1), R8
	MOVQ	(56)(REG_P1), R9
	MOVQ	(64)(REG_P1), R10
	MOVQ	(72)(REG_P1), R11
	MOVQ	(80)(REG_P1), R12
	MOVQ	(88)(REG_P1), R13
	ADDQ	(REG_P1), R8
	ADCQ	(8)(REG_P1), R9
	ADCQ	(16)(REG_P1), R10
	ADCQ	(24)(REG_P1), R11
	ADCQ	(32)(REG_P1), R12
	ADCQ	(40)(REG_P1), R13
	MOVQ	R8, (CX)
	MOVQ	R9, (8)(CX)
	MOVQ	R10, (16)(CX)
	MOVQ	R11, (24)(CX)
	MOVQ	R12, (32)(CX)
	MOVQ	R13, (40)(CX)
	SBBQ	$0, AX

	XORQ	DX, DX
	MOVQ	(48)(REG_P2), R8
	MOVQ	(56)(REG_P2), R9
	MOVQ	(64)(REG_P2), R10
	MOVQ	(72)(REG_P2), R11
	MOVQ	(80)(REG_P2), R12
	MOVQ	(88)(REG_P2), R13
	ADDQ	(REG_P2), R8
	ADCQ	(8)(REG_P2), R9
	ADCQ	(16)(REG_P2), R10
	ADCQ	(24)(REG_P2), R11
	ADCQ	(32)(REG_P2), R12
	ADCQ	(40)(REG_P2), R13
	MOVQ	R8, (48)(CX)
	MOVQ	R9, (56)(CX)
	MOVQ	R10, (64)(CX)
	MOVQ	R11, (72)(CX)
	MOVQ	R12, (80)(CX)
	MOVQ	R13, (88)(CX)
	SBBQ	$0, DX
	MOVQ	AX, (80)(SP)
	MOVQ	DX, (88)(SP)

	// (SP[0-8],R10,R8,R9) <- (AH+AL)*(BH+BL)

	MOVQ	(CX), R11
	MOVQ	R8, AX
	MULQ	R11
	MOVQ	AX, (SP)		// c0
	MOVQ	DX, R14

	XORQ	R15, R15
	MOVQ	R9, AX
	MULQ	R11
	XORQ	R9, R9
	ADDQ	AX, R14
	ADCQ	DX, R9

	MOVQ	(8)(CX), R12
	MOVQ	R8, AX
	MULQ	R12
	ADDQ	AX, R14
	MOVQ	R14, (8)(SP)		// c1
	ADCQ	DX, R9
	ADCQ	$0, R15

	XORQ	R8, R8
	MOVQ	R10, AX
	MULQ	R11
	ADDQ	AX, R9
	MOVQ	(48)(CX), R13
	ADCQ	DX, R15
	ADCQ	$0, R8

	MOVQ	(16)(CX), AX
	MULQ	R13
	ADDQ	AX, R9
	ADCQ	DX, R15
	MOVQ	(56)(CX), AX
	ADCQ	$0, R8

	MULQ	R12
	ADDQ	AX, R9
	MOVQ	R9, (16)(SP)		// c2
	ADCQ	DX, R15
	ADCQ	$0, R8

	XORQ	R9, R9
	MOVQ	(72)(CX), AX
	MULQ	R11
	ADDQ	AX, R15
	ADCQ	DX, R8
	ADCQ	$0, R9

	MOVQ	(24)(CX), AX
	MULQ	R13
	ADDQ	AX, R15
	ADCQ	DX, R8
	ADCQ	$0, R9

	MOVQ	R10, AX
	MULQ	R12
	ADDQ	AX, R15
	ADCQ	DX, R8
	ADCQ	$0, R9

	MOVQ	(16)(CX), R14
	MOVQ	(56)(CX), AX
	MULQ	R14
	ADDQ	AX, R15
	MOVQ	R15, (24)(SP)		// c3
	ADCQ	DX, R8
	ADCQ	$0, R9

	XORQ	R10, R10
	MOVQ	(80)(CX), AX
	MULQ	R11
	ADDQ	AX, R8
	ADCQ	DX, R9
	ADCQ	$0, R10

	MOVQ	(64)(CX), AX
	MULQ	R14
	ADDQ	AX, R8
	ADCQ	DX, R9
	ADCQ	$0, R10

	MOVQ	(48)(CX), R15
	MOVQ	(32)(CX), AX
	MULQ	R15
	ADDQ	AX, R8
	ADCQ	DX, R9
	ADCQ	$0, R10

	MOVQ	(72)(CX), AX
	MULQ	R12
	ADDQ	AX, R8
	ADCQ	DX, R9
	ADCQ	$0, R10

	MOVQ	(24)(CX), R13
	MOVQ	(56)(CX), AX
	MULQ	R13
	ADDQ	AX, R8
	MOVQ	R8, (32)(SP)		// c4
	ADCQ	DX, R9
	ADCQ	$0, R10

	XORQ	R8, R8
	MOVQ	(88)(CX), AX
	MULQ	R11
	ADDQ	AX, R9
	ADCQ	DX, R10
	ADCQ	$0, R8

	MOVQ	(64)(CX), AX
	MULQ	R13
	ADDQ	AX, R9
	ADCQ	DX, R10
	ADCQ	$0, R8

	MOVQ	(72)(CX), AX
	MULQ	R14
	ADDQ	AX, R9
	ADCQ	DX, R10
	ADCQ	$0, R8

	MOVQ	(40)(CX), AX
	MULQ	R15
	ADDQ	AX, R9
	ADCQ	DX, R10
	ADCQ	$0, R8

	MOVQ	(80)(CX), AX
	MULQ	R12
	ADDQ	AX, R9
	ADCQ	DX, R10
	ADCQ	$0, R8

	MOVQ	(32)(CX), R15
	MOVQ	(56)(CX), AX
	MULQ	R15
	ADDQ	AX, R9
	MOVQ	R9, (40)(SP)		// c5
	ADCQ	DX, R10
	ADCQ	$0, R8

	XORQ	R9, R9
	MOVQ	(64)(CX), AX
	MULQ	R15
	ADDQ	AX, R10
	ADCQ	DX, R8
	ADCQ	$0, R9

	MOVQ	(88)(CX), AX
	MULQ	R12
	ADDQ	AX, R10
	ADCQ	DX, R8
	ADCQ	$0, R9

	MOVQ	(80)(CX), AX
	MULQ	R14
	ADDQ	AX, R10
	ADCQ	DX, R8
	ADCQ	$0, R9

	MOVQ	(40)(CX), R11
	MOVQ	(56)(CX), AX
	MULQ	R11
	ADDQ	AX, R10
	ADCQ	DX, R8
	ADCQ	$0, R9

	MOVQ	(72)(CX), AX
	MULQ	R13
	ADDQ	AX, R10
	MOVQ	R10, (48)(SP)		// c6
	ADCQ	DX, R8
	ADCQ	$0, R9

	XORQ	R10, R10
	MOVQ	(88)(CX), AX
	MULQ	R14
	ADDQ	AX, R8
	ADCQ	DX, R9
	ADCQ	$0, R10

	MOVQ	(64)(CX), AX
	MULQ	R11
	ADDQ	AX, R8
	ADCQ	DX, R9
	ADCQ	$0, R10

	MOVQ	(80)(CX), AX
	MULQ	R13
	ADDQ	AX, R8
	ADCQ	DX, R9
	ADCQ	$0, R10

	MOVQ	(72)(CX), AX
	MULQ	R15
	ADDQ	AX, R8
	MOVQ	R8, (56)(SP)		// c7
	ADCQ	DX, R9
	ADCQ	$0, R10

	XORQ	R8, R8
	MOVQ	(72)(CX), AX
	MULQ	R11
	ADDQ	AX, R9
	ADCQ	DX, R10
	ADCQ	$0, R8

	MOVQ	(80)(CX), AX
	MULQ	R15
	ADDQ	AX, R9
	ADCQ	DX, R10
	ADCQ	$0, R8

	MOVQ	(88)(CX), AX
	MULQ	R13
	ADDQ	AX, R9
	MOVQ	R9, (64)(SP)		// c8
	ADCQ	DX, R10
	ADCQ	$0, R8

	XORQ	R9, R9
	MOVQ	(88)(CX), AX
	MULQ	R15
	ADDQ	AX, R10
	ADCQ	DX, R8
	ADCQ	$0, R9

	MOVQ	(80)(CX), AX
	MULQ	R11
	ADDQ	AX, R10			// c9
	ADCQ	DX, R8
	ADCQ	$0, R9

	MOVQ	(88)(CX), AX
	MULQ	R11
	ADDQ	AX, R8			// c10
	ADCQ	DX, R9			// c11

	MOVQ	(88)(SP), AX
	MOVQ	(CX), DX
	ANDQ	AX, R12
	ANDQ	AX, R14
	ANDQ	AX, DX
	ANDQ	AX, R13
	ANDQ	AX, R15
	ANDQ	AX, R11
	MOVQ	(48)(SP), AX
	ADDQ	AX, DX
	MOVQ	(56)(SP), AX
	ADCQ	AX, R12
	MOVQ	(64)(SP), AX
	ADCQ	AX, R14
	ADCQ	R10, R13
	ADCQ	R8, R15
	ADCQ	R9, R11
	MOVQ	(80)(SP), AX
	MOVQ	DX, (48)(SP)
	MOVQ	R12, (56)(SP)
	MOVQ	R14, (64)(SP)
	MOVQ	R13, (72)(SP)
	MOVQ	R15, (80)(SP)
	MOVQ	R11, (88)(SP)

	MOVQ	(48)(CX), R8
	MOVQ	(56)(CX), R9
	MOVQ	(64)(CX), R10
	MOVQ	(72)(CX), R11
	MOVQ	(80)(CX), R12
	MOVQ	(88)(CX), R13
	ANDQ	AX, R8
	ANDQ	AX, R9
	ANDQ	AX, R10
	ANDQ	AX, R11
	ANDQ	AX, R12
	ANDQ	AX, R13
	MOVQ	(48)(SP), AX
	ADDQ	AX, R8
	MOVQ	(56)(SP), AX
	ADCQ	AX, R9
	MOVQ	(64)(SP), AX
	ADCQ	AX, R10
	MOVQ	(72)(SP), AX
	ADCQ	AX, R11
	MOVQ	(80)(SP), AX
	ADCQ	AX, R12
	MOVQ	(88)(SP), AX
	ADCQ	AX, R13
	MOVQ	R8, (48)(SP)
	MOVQ	R9, (56)(SP)
	MOVQ	R11, (72)(SP)

	// CX[0-11] <- AL*BL
	MOVQ	(REG_P1), R11
	MOVQ	(REG_P2), AX
	MULQ	R11
	XORQ	R9, R9
	MOVQ	AX, (CX)		// c0
	MOVQ	R10, (64)(SP)
	MOVQ	DX, R8

	MOVQ	(8)(REG_P2), AX
	MULQ	R11
	XORQ	R10, R10
	ADDQ	AX, R8
	MOVQ	R12, (80)(SP)
	ADCQ	DX, R9

	MOVQ	(8)(REG_P1), R12
	MOVQ	(REG_P2), AX
	MULQ	R12
	ADDQ	AX, R8
	MOVQ	R8, (8)(CX)		// c1
	ADCQ	DX, R9
	MOVQ	R13, (88)(SP)
	ADCQ	$0, R10

	XORQ	R8, R8
	MOVQ	(16)(REG_P2), AX
	MULQ	R11
	ADDQ	AX, R9
	ADCQ	DX, R10
	ADCQ	$0, R8

	MOVQ	(REG_P2), R13
	MOVQ	(16)(REG_P1), AX
	MULQ	R13
	ADDQ	AX, R9
	ADCQ	DX, R10
	ADCQ	$0, R8

	MOVQ	(8)(REG_P2), AX
	MULQ	R12
	ADDQ	AX, R9
	MOVQ	R9, (16)(CX)		// c2
	ADCQ	DX, R10
	ADCQ	$0, R8

	XORQ	R9, R9
	MOVQ	(24)(REG_P2), AX
	MULQ	R11
	ADDQ	AX, R10
	ADCQ	DX, R8
	ADCQ	$0, R9

	MOVQ	(24)(REG_P1), AX
	MULQ	R13
	ADDQ	AX, R10
	ADCQ	DX, R8
	ADCQ	$0, R9

	MOVQ	(16)(REG_P2), AX
	MULQ	R12
	ADDQ	AX, R10
	ADCQ	DX, R8
	ADCQ	$0, R9

	MOVQ	(16)(REG_P1), R14
	MOVQ	(8)(REG_P2), AX
	MULQ	R14
	ADDQ	AX, R10
	MOVQ	R10, (24)(CX)		// c3
	ADCQ	DX, R8
	ADCQ	$0, R9

	XORQ	R10, R10
	MOVQ	(32)(REG_P2), AX
	MULQ	R11
	ADDQ	AX, R8
	ADCQ	DX, R9
	ADCQ	$0, R10

	MOVQ	(16)(REG_P2), AX
	MULQ	R14
	ADDQ	AX, R8
	ADCQ	DX, R9
	ADCQ	$0, R10

	MOVQ	(32)(REG_P1), AX
	MULQ	R13
	ADDQ	AX, R8
	ADCQ	DX, R9
	ADCQ	$0, R10

	MOVQ	(24)(REG_P2), AX
	MULQ	R12
	ADDQ	AX, R8
	ADCQ	DX, R9
	ADCQ	$0, R10

	MOVQ	(24)(REG_P1), R13
	MOVQ	(8)(REG_P2), AX
	MULQ	R13
	ADDQ	AX, R8
	MOVQ	R8, (32)(CX)		// c4
	ADCQ	DX, R9
	ADCQ	$0, R10

	XORQ	R8, R8
	MOVQ	(40)(REG_P2), AX
	MULQ	R11
	ADDQ	AX, R9
	ADCQ	DX, R10
	ADCQ	$0, R8

	MOVQ	(16)(REG_P2), AX
	MULQ	R13
	ADDQ	AX, R9
	ADCQ	DX, R10
	ADCQ	$0, R8

	MOVQ	(24)(REG_P2), AX
	MULQ	R14
	ADDQ	AX, R9
	ADCQ	DX, R10
	ADCQ	$0, R8

	MOVQ	(40)(REG_P1), R11
	MOVQ	(REG_P2), AX
	MULQ	R11
	ADDQ	AX, R9
	ADCQ	DX, R10
	ADCQ	$0, R8

	MOVQ	(32)(REG_P2), AX
	MULQ	R12
	ADDQ	AX, R9
	ADCQ	DX, R10
	ADCQ	$0, R8

	MOVQ	(32)(REG_P1), R15
	MOVQ	(8)(REG_P2), AX
	MULQ	R15
	ADDQ	AX, R9
	MOVQ	R9, (40)(CX)		//c5
	ADCQ	DX, R10
	ADCQ	$0, R8

	XORQ	R9, R9
	MOVQ	(16)(REG_P2), AX
	MULQ	R15
	ADDQ	AX, R10
	ADCQ	DX, R8
	ADCQ	$0, R9

	MOVQ	(40)(REG_P2), AX
	MULQ	R12
	ADDQ	AX, R10
	ADCQ	DX, R8
	ADCQ	$0, R9

	MOVQ	(32)(REG_P2), AX
	MULQ	R14
	ADDQ	AX, R10
	ADCQ	DX, R8
	ADCQ	$0, R9

	MOVQ	(8)(REG_P2), AX
	MULQ	R11
	ADDQ	AX, R10
	ADCQ	DX, R8
	ADCQ	$0, R9

	MOVQ	(24)(REG_P2), AX
	MULQ	R13
	ADDQ	AX, R10
	MOVQ	R10, (48)(CX)		// c6
	ADCQ	DX, R8
	ADCQ	$0, R9

	XORQ	R10, R10
	MOVQ	(40)(REG_P2), AX
	MULQ	R14
	ADDQ	AX, R8
	ADCQ	DX, R9
	ADCQ	$0, R10

	MOVQ	(16)(REG_P2), AX
	MULQ	R11
	ADDQ	AX, R8
	ADCQ	DX, R9
	ADCQ	$0, R10

	MOVQ	(32)(REG_P2), AX
	MULQ	R13
	ADDQ	AX, R8
	ADCQ	DX, R9
	ADCQ	$0, R10

	MOVQ	(24)(REG_P2), AX
	MULQ	R15
	ADDQ	AX, R8
	MOVQ	R8, (56)(CX)		// c7
	ADCQ	DX, R9
	ADCQ	$0, R10

	XORQ	R8, R8
	MOVQ	(24)(REG_P2), AX
	MULQ	R11
	ADDQ	AX, R9
	ADCQ	DX, R10
	ADCQ	$0, R8

	MOVQ	(32)(REG_P2), AX
	MULQ	R15
	ADDQ	AX, R9
	ADCQ	DX, R10
	ADCQ	$0, R8

	MOVQ	(40)(REG_P2), AX
	MULQ	R13
	ADDQ	AX, R9
	MOVQ	R9, (64)(CX)		// c8
	ADCQ	DX, R10
	ADCQ	$0, R8

	XORQ	R9, R9
	MOVQ	(40)(REG_P2), AX
	MULQ	R15
	ADDQ	AX, R10
	ADCQ	DX, R8
	ADCQ	$0, R9

	MOVQ	(32)(REG_P2), AX
	MULQ	R11
	ADDQ	AX, R10
	MOVQ	R10, (72)(CX)		// c9
	ADCQ	DX, R8
	ADCQ	$0, R9

	MOVQ	(40)(REG_P2), AX
	MULQ	R11
	ADDQ	AX, R8
	MOVQ	R8, (80)(CX)		// c10
	ADCQ	DX, R9
	MOVQ	R9, (88)(CX)		// c11

	// CX[12-23] <- AH*BH
	MOVQ	(48)(REG_P1), R11
	MOVQ	(48)(REG_P2), AX
	MULQ	R11
	XORQ	R9, R9
	MOVQ	AX, (96)(CX)		// c0
	MOVQ	DX, R8

	MOVQ	(56)(REG_P2), AX
	MULQ	R11
	XORQ	R10, R10
	ADDQ	AX, R8
	ADCQ	DX, R9

	MOVQ	(56)(REG_P1), R12
	MOVQ	(48)(REG_P2), AX
	MULQ	R12
	ADDQ	AX, R8
	MOVQ	R8, (104)(CX)		// c1
	ADCQ	DX, R9
	ADCQ	$0, R10

	XORQ	R8, R8
	MOVQ	(64)(REG_P2), AX
	MULQ	R11
	ADDQ	AX, R9
	ADCQ	DX, R10
	ADCQ	$0, R8

	MOVQ	(48)(REG_P2), R13
	MOVQ	(64)(REG_P1), AX
	MULQ	R13
	ADDQ	AX, R9
	ADCQ	DX, R10
	ADCQ	$0, R8

	MOVQ	(56)(REG_P2), AX
	MULQ	R12
	ADDQ	AX, R9
	MOVQ	R9, (112)(CX)		// c2
	ADCQ	DX, R10
	ADCQ	$0, R8

	XORQ	R9, R9
	MOVQ	(72)(REG_P2), AX
	MULQ	R11
	ADDQ	AX, R10
	ADCQ	DX, R8
	ADCQ	$0, R9

	MOVQ	(72)(REG_P1), AX
	MULQ	R13
	ADDQ	AX, R10
	ADCQ	DX, R8
	ADCQ	$0, R9

	MOVQ	(64)(REG_P2), AX
	MULQ	R12
	ADDQ	AX, R10
	ADCQ	DX, R8
	ADCQ	$0, R9

	MOVQ	(64)(REG_P1), R14
	MOVQ	(56)(REG_P2), AX
	MULQ	R14
	ADDQ	AX, R10
	MOVQ	R10, (120)(CX)		// c3
	ADCQ	DX, R8
	ADCQ	$0, R9

	XORQ	R10, R10
	MOVQ	(80)(REG_P2), AX
	MULQ	R11
	ADDQ	AX, R8
	ADCQ	DX, R9
	ADCQ	$0, R10

	MOVQ	(64)(REG_P2), AX
	MULQ	R14
	ADDQ	AX, R8
	ADCQ	DX, R9
	ADCQ	$0, R10

	MOVQ	(80)(REG_P1), R15
	MOVQ	R13, AX
	MULQ	R15
	ADDQ	AX, R8
	ADCQ	DX, R9
	ADCQ	$0, R10

	MOVQ	(72)(REG_P2), AX
	MULQ	R12
	ADDQ	AX, R8
	ADCQ	DX, R9
	ADCQ	$0, R10

	MOVQ	(72)(REG_P1), R13
	MOVQ	(56)(REG_P2), AX
	MULQ	R13
	ADDQ	AX, R8
	MOVQ	R8, (128)(CX)		// c4
	ADCQ	DX, R9
	ADCQ	$0, R10

	XORQ	R8, R8
	MOVQ	(88)(REG_P2), AX
	MULQ	R11
	ADDQ	AX, R9
	ADCQ	DX, R10
	ADCQ	$0, R8

	MOVQ	(64)(REG_P2), AX
	MULQ	R13
	ADDQ	AX, R9
	ADCQ	DX, R10
	ADCQ	$0, R8

	MOVQ	(72)(REG_P2), AX
	MULQ	R14
	ADDQ	AX, R9
	ADCQ	DX, R10
	ADCQ	$0, R8

	MOVQ	(88)(REG_P1), R11
	MOVQ	(48)(REG_P2), AX
	MULQ	R11
	ADDQ	AX, R9
	ADCQ	DX, R10
	ADCQ	$0, R8

	MOVQ	(80)(REG_P2), AX
	MULQ	R12
	ADDQ	AX, R9
	ADCQ	DX, R10
	ADCQ	$0, R8

	MOVQ	(56)(REG_P2), AX
	MULQ	R15
	ADDQ	AX, R9
	MOVQ	R9, (136)(CX)		// c5
	ADCQ	DX, R10
	ADCQ	$0, R8

	XORQ	R9, R9
	MOVQ	(64)(REG_P2), AX
	MULQ	R15
	ADDQ	AX, R10
	ADCQ	DX, R8
	ADCQ	$0, R9

	MOVQ	(88)(REG_P2), AX
	MULQ	R12
	ADDQ	AX, R10
	ADCQ	DX, R8
	ADCQ	$0, R9

	MOVQ	(80)(REG_P2), AX
	MULQ	R14
	ADDQ	AX, R10
	ADCQ	DX, R8
	ADCQ	$0, R9

	MOVQ	(56)(REG_P2), AX
	MULQ	R11
	ADDQ	AX, R10
	ADCQ	DX, R8
	ADCQ	$0, R9

	MOVQ	(72)(REG_P2), AX
	MULQ	R13
	ADDQ	AX, R10
	MOVQ	R10, (144)(CX)		// c6
	ADCQ	DX, R8
	ADCQ	$0, R9

	XORQ	R10, R10
	MOVQ	(88)(REG_P2), AX
	MULQ	R14
	ADDQ	AX, R8
	ADCQ	DX, R9
	ADCQ	$0, R10

	MOVQ	(64)(REG_P2), AX
	MULQ	R11
	ADDQ	AX, R8
	ADCQ	DX, R9
	ADCQ	$0, R10

	MOVQ	(80)(REG_P2), AX
	MULQ	R13
	ADDQ	AX, R8
	ADCQ	DX, R9
	ADCQ	$0, R10

	MOVQ	(72)(REG_P2), AX
	MULQ	R15
	ADDQ	AX, R8
	MOVQ	R8, (152)(CX)		// c7
	ADCQ	DX, R9
	ADCQ	$0, R10

	XORQ	R8, R8
	MOVQ	(72)(REG_P2), AX
	MULQ	R11
	ADDQ	AX, R9
	ADCQ	DX, R10
	ADCQ	$0, R8

	MOVQ	(80)(REG_P2), AX
	MULQ	R15
	ADDQ	AX, R9
	ADCQ	DX, R10
	ADCQ	$0, R8

	MOVQ	(88)(REG_P2), AX
	MULQ	R13
	ADDQ	AX, R9
	MOVQ	R9, (160)(CX)		// c8
	ADCQ	DX, R10
	ADCQ	$0, R8

	MOVQ	(88)(REG_P2), AX
	MULQ	R15
	ADDQ	AX, R10
	ADCQ	DX, R8

	MOVQ	(80)(REG_P2), AX
	MULQ	R11
	ADDQ	AX, R10
	MOVQ	R10, (168)(CX)		// c9
	ADCQ	DX, R8

	MOVQ	(88)(REG_P2), AX
	MULQ	R11
	ADDQ	AX, R8
	MOVQ	R8, (176)(CX)		// c10
	ADCQ	$0, DX
	MOVQ	DX, (184)(CX)		// c11

	// [R8-R15,AX,DX,DI,(SP)] <- (AH+AL)*(BH+BL)-AL*BL
	MOVQ	(SP), R8
	SUBQ	(CX), R8
	MOVQ	(8)(SP), R9
	SBBQ	(8)(CX), R9
	MOVQ	(16)(SP), R10
	SBBQ	(16)(CX), R10
	MOVQ	(24)(SP), R11
	SBBQ	(24)(CX), R11
	MOVQ	(32)(SP), R12
	SBBQ	(32)(CX), R12
	MOVQ	(40)(SP), R13
	SBBQ	(40)(CX), R13
	MOVQ	(48)(SP), R14
	SBBQ	(48)(CX), R14
	MOVQ	(56)(SP), R15
	SBBQ	(56)(CX), R15
	MOVQ	(64)(SP), AX
	SBBQ	(64)(CX), AX
	MOVQ	(72)(SP), DX
	SBBQ	(72)(CX), DX
	MOVQ	(80)(SP), DI
	SBBQ	(80)(CX), DI
	MOVQ	(88)(SP), SI
	SBBQ	(88)(CX), SI
	MOVQ	SI, (SP)

	// [R8-R15,AX,DX,DI,(SP)] <- (AH+AL)*(BH+BL) - AL*BL - AH*BH
	MOVQ	(96)(CX), SI
	SUBQ	SI, R8
	MOVQ	(104)(CX), SI
	SBBQ	SI, R9
	MOVQ	(112)(CX), SI
	SBBQ	SI, R10
	MOVQ	(120)(CX), SI
	SBBQ	SI, R11
	MOVQ	(128)(CX), SI
	SBBQ	SI, R12
	MOVQ	(136)(CX), SI
	SBBQ	SI, R13
	MOVQ	(144)(CX), SI
	SBBQ	SI, R14
	MOVQ	(152)(CX), SI
	SBBQ	SI, R15
	MOVQ	(160)(CX), SI
	SBBQ	SI, AX
	MOVQ	(168)(CX), SI
	SBBQ	SI, DX
	MOVQ	(176)(CX), SI
	SBBQ	SI, DI
	MOVQ	(SP), SI
	SBBQ	(184)(CX), SI

	// FINAL RESULT
	ADDQ	(48)(CX), R8
	MOVQ	R8, (48)(CX)
	ADCQ	(56)(CX), R9
	MOVQ	R9, (56)(CX)
	ADCQ	(64)(CX), R10
	MOVQ	R10, (64)(CX)
	ADCQ	(72)(CX), R11
	MOVQ	R11, (72)(CX)
	ADCQ	(80)(CX), R12
	MOVQ	R12, (80)(CX)
	ADCQ	(88)(CX), R13
	MOVQ	R13, (88)(CX)
	ADCQ	(96)(CX), R14
	MOVQ	R14, (96)(CX)
	ADCQ	(104)(CX), R15
	MOVQ	R15, (104)(CX)
	ADCQ	(112)(CX), AX
	MOVQ	AX, (112)(CX)
	ADCQ	(120)(CX), DX
	MOVQ	DX, (120)(CX)
	ADCQ	(128)(CX), DI
	MOVQ	DI, (128)(CX)
	ADCQ	(136)(CX), SI
	MOVQ	SI, (136)(CX)
	MOVQ	(144)(CX), AX
	ADCQ	$0, AX
	MOVQ	AX, (144)(CX)
	MOVQ	(152)(CX), AX
	ADCQ	$0, AX
	MOVQ	AX, (152)(CX)
	MOVQ	(160)(CX), AX
	ADCQ	$0, AX
	MOVQ	AX, (160)(CX)
	MOVQ	(168)(CX), AX
	ADCQ	$0, AX
	MOVQ	AX, (168)(CX)
	MOVQ	(176)(CX), AX
	ADCQ	$0, AX
	MOVQ	AX, (176)(CX)
	MOVQ	(184)(CX), AX
	ADCQ	$0, AX
	MOVQ	AX, (184)(CX)

	RET

TEXT ·fp751MontgomeryReduce(SB), $0-16

	MOVQ z+0(FP), REG_P2
	MOVQ x+8(FP), REG_P1

	MOVQ	(REG_P1), R11
	MOVQ	P751P1_5, AX
	MULQ	R11
	XORQ	R8, R8
	ADDQ	(40)(REG_P1), AX
	MOVQ	AX, (40)(REG_P2)		// Z5
	ADCQ	DX, R8

	XORQ	R9, R9
	MOVQ	P751P1_6, AX
	MULQ	R11
	XORQ	R10, R10
	ADDQ	AX, R8
	ADCQ	DX, R9

	MOVQ	(8)(REG_P1), R12
	MOVQ	P751P1_5, AX
	MULQ	R12
	ADDQ	AX, R8
	ADCQ	DX, R9
	ADCQ	$0, R10
	ADDQ	(48)(REG_P1), R8
	MOVQ	R8, (48)(REG_P2)		// Z6
	ADCQ	$0, R9
	ADCQ	$0, R10

	XORQ	R8, R8
	MOVQ	P751P1_7, AX
	MULQ	R11
	ADDQ	AX, R9
	ADCQ	DX, R10
	ADCQ	$0, R8

	MOVQ	P751P1_6, AX
	MULQ	R12
	ADDQ	AX, R9
	ADCQ	DX, R10
	ADCQ	$0, R8

	MOVQ	(16)(REG_P1), R13
	MOVQ	P751P1_5, AX
	MULQ	R13
	ADDQ	AX, R9
	ADCQ	DX, R10
	ADCQ	$0, R8
	ADDQ	(56)(REG_P1), R9
	MOVQ	R9, (56)(REG_P2)		// Z7
	ADCQ	$0, R10
	ADCQ	$0, R8

	XORQ	R9, R9
	MOVQ	P751P1_8, AX
	MULQ	R11
	ADDQ	AX, R10
	ADCQ	DX, R8
	ADCQ	$0, R9

	MOVQ	P751P1_7, AX
	MULQ	R12
	ADDQ	AX, R10
	ADCQ	DX, R8
	ADCQ	$0, R9

	MOVQ	P751P1_6, AX
	MULQ	R13
	ADDQ	AX, R10
	ADCQ	DX, R8
	ADCQ	$0, R9

	MOVQ	(24)(REG_P1), R14
	MOVQ	P751P1_5, AX
	MULQ	R14
	ADDQ	AX, R10
	ADCQ	DX, R8
	ADCQ	$0, R9
	ADDQ	(64)(REG_P1), R10
	MOVQ	R10, (64)(REG_P2)		// Z8
	ADCQ	$0, R8
	ADCQ	$0, R9

	XORQ	R10, R10
	MOVQ	P751P1_9, AX
	MULQ	R11
	ADDQ	AX, R8
	ADCQ	DX, R9
	ADCQ	$0, R10

	MOVQ	P751P1_8, AX
	MULQ	R12
	ADDQ	AX, R8
	ADCQ	DX, R9
	ADCQ	$0, R10

	MOVQ	P751P1_7, AX
	MULQ	R13
	ADDQ	AX, R8
	ADCQ	DX, R9
	ADCQ	$0, R10

	MOVQ	P751P1_6, AX
	MULQ	R14
	ADDQ	AX, R8
	ADCQ	DX, R9
	ADCQ	$0, R10

	MOVQ	(32)(REG_P1), R15
	MOVQ	P751P1_5, AX
	MULQ	R15
	ADDQ	AX, R8
	ADCQ	DX, R9
	ADCQ	$0, R10
	ADDQ	(72)(REG_P1), R8
	MOVQ	R8, (72)(REG_P2)		// Z9
	ADCQ	$0, R9
	ADCQ	$0, R10

	XORQ	R8, R8
	MOVQ	P751P1_10, AX
	MULQ	R11
	ADDQ	AX, R9
	ADCQ	DX, R10
	ADCQ	$0, R8

	MOVQ	P751P1_9, AX
	MULQ	R12
	ADDQ	AX, R9
	ADCQ	DX, R10
	ADCQ	$0, R8

	MOVQ	P751P1_8, AX
	MULQ	R13
	ADDQ	AX, R9
	ADCQ	DX, R10
	ADCQ	$0, R8

	MOVQ	P751P1_7, AX
	MULQ	R14
	ADDQ	AX, R9
	ADCQ	DX, R10
	ADCQ	$0, R8

	MOVQ	P751P1_6, AX
	MULQ	R15
	ADDQ	AX, R9
	ADCQ	DX, R10
	ADCQ	$0, R8

	MOVQ	(40)(REG_P2), CX
	MOVQ	P751P1_5, AX
	MULQ	CX
	ADDQ	AX, R9
	ADCQ	DX, R10
	ADCQ	$0, R8
	ADDQ	(80)(REG_P1), R9
	MOVQ	R9, (80)(REG_P2)		// Z10
	ADCQ	$0, R10
	ADCQ	$0, R8

	XORQ	R9, R9
	MOVQ	P751P1_11, AX
	MULQ	R11
	ADDQ	AX, R10
	ADCQ	DX, R8
	ADCQ	$0, R9

	MOVQ	P751P1_10, AX
	MULQ	R12
	ADDQ	AX, R10
	ADCQ	DX, R8
	ADCQ	$0, R9

	MOVQ	P751P1_9, AX
	MULQ	R13
	ADDQ	AX, R10
	ADCQ	DX, R8
	ADCQ	$0, R9

	MOVQ	P751P1_8, AX
	MULQ	R14
	ADDQ	AX, R10
	ADCQ	DX, R8
	ADCQ	$0, R9

	MOVQ	P751P1_7, AX
	MULQ	R15
	ADDQ	AX, R10
	ADCQ	DX, R8
	ADCQ	$0, R9

	MOVQ	P751P1_6, AX
	MULQ	CX
	ADDQ	AX, R10
	ADCQ	DX, R8
	ADCQ	$0, R9

	MOVQ	(48)(REG_P2), R11
	MOVQ	P751P1_5, AX
	MULQ	R11
	ADDQ	AX, R10
	ADCQ	DX, R8
	ADCQ	$0, R9
	ADDQ	(88)(REG_P1), R10
	MOVQ	R10, (88)(REG_P2)		// Z11
	ADCQ	$0, R8
	ADCQ	$0, R9

	XORQ	R10, R10
	MOVQ	P751P1_11, AX
	MULQ	R12
	ADDQ	AX, R8
	ADCQ	DX, R9
	ADCQ	$0, R10

	MOVQ	P751P1_10, AX
	MULQ	R13
	ADDQ	AX, R8
	ADCQ	DX, R9
	ADCQ	$0, R10

	MOVQ	P751P1_9, AX
	MULQ	R14
	ADDQ	AX, R8
	ADCQ	DX, R9
	ADCQ	$0, R10

	MOVQ	P751P1_8, AX
	MULQ	R15
	ADDQ	AX, R8
	ADCQ	DX, R9
	ADCQ	$0, R10

	MOVQ	P751P1_7, AX
	MULQ	CX
	ADDQ	AX, R8
	ADCQ	DX, R9
	ADCQ	$0, R10

	MOVQ	P751P1_6, AX
	MULQ	R11
	ADDQ	AX, R8
	ADCQ	DX, R9
	ADCQ	$0, R10

	MOVQ	(56)(REG_P2), R12
	MOVQ	P751P1_5, AX
	MULQ	R12
	ADDQ	AX, R8
	ADCQ	DX, R9
	ADCQ	$0, R10
	ADDQ	(96)(REG_P1), R8
	MOVQ	R8, (REG_P2)		// Z0
	ADCQ	$0, R9
	ADCQ	$0, R10

	XORQ	R8, R8
	MOVQ	P751P1_11, AX
	MULQ	R13
	ADDQ	AX, R9
	ADCQ	DX, R10
	ADCQ	$0, R8

	MOVQ	P751P1_10, AX
	MULQ	R14
	ADDQ	AX, R9
	ADCQ	DX, R10
	ADCQ	$0, R8

	MOVQ	P751P1_9, AX
	MULQ	R15
	ADDQ	AX, R9
	ADCQ	DX, R10
	ADCQ	$0, R8

	MOVQ	P751P1_8, AX
	MULQ	CX
	ADDQ	AX, R9
	ADCQ	DX, R10
	ADCQ	$0, R8

	MOVQ	P751P1_7, AX
	MULQ	R11
	ADDQ	AX, R9
	ADCQ	DX, R10
	ADCQ	$0, R8

	MOVQ	P751P1_6, AX
	MULQ	R12
	ADDQ	AX, R9
	ADCQ	DX, R10
	ADCQ	$0, R8

	MOVQ	(64)(REG_P2), R13
	MOVQ	P751P1_5, AX
	MULQ	R13
	ADDQ	AX, R9
	ADCQ	DX, R10
	ADCQ	$0, R8
	ADDQ	(104)(REG_P1), R9
	MOVQ	R9, (8)(REG_P2)		// Z1
	ADCQ	$0, R10
	ADCQ	$0, R8

	XORQ	R9, R9
	MOVQ	P751P1_11, AX
	MULQ	R14
	ADDQ	AX, R10
	ADCQ	DX, R8
	ADCQ	$0, R9

	MOVQ	P751P1_10, AX
	MULQ	R15
	ADDQ	AX, R10
	ADCQ	DX, R8
	ADCQ	$0, R9

	MOVQ	P751P1_9, AX
	MULQ	CX
	ADDQ	AX, R10
	ADCQ	DX, R8
	ADCQ	$0, R9

	MOVQ	P751P1_8, AX
	MULQ	R11
	ADDQ	AX, R10
	ADCQ	DX, R8
	ADCQ	$0, R9

	MOVQ	P751P1_7, AX
	MULQ	R12
	ADDQ	AX, R10
	ADCQ	DX, R8
	ADCQ	$0, R9

	MOVQ	P751P1_6, AX
	MULQ	R13
	ADDQ	AX, R10
	ADCQ	DX, R8
	ADCQ	$0, R9

	MOVQ	(72)(REG_P2), R14
	MOVQ	P751P1_5, AX
	MULQ	R14
	ADDQ	AX, R10
	ADCQ	DX, R8
	ADCQ	$0, R9
	ADDQ	(112)(REG_P1), R10
	MOVQ	R10, (16)(REG_P2)		// Z2
	ADCQ	$0, R8
	ADCQ	$0, R9

	XORQ	R10, R10
	MOVQ	P751P1_11, AX
	MULQ	R15
	ADDQ	AX, R8
	ADCQ	DX, R9
	ADCQ	$0, R10

	MOVQ	P751P1_10, AX
	MULQ	CX
	ADDQ	AX, R8
	ADCQ	DX, R9
	ADCQ	$0, R10

	MOVQ	P751P1_9, AX
	MULQ	R11
	ADDQ	AX, R8
	ADCQ	DX, R9
	ADCQ	$0, R10

	MOVQ	P751P1_8, AX
	MULQ	R12
	ADDQ	AX, R8
	ADCQ	DX, R9
	ADCQ	$0, R10

	MOVQ	P751P1_7, AX
	MULQ	R13
	ADDQ	AX, R8
	ADCQ	DX, R9
	ADCQ	$0, R10

	MOVQ	P751P1_6, AX
	MULQ	R14
	ADDQ	AX, R8
	ADCQ	DX, R9
	ADCQ	$0, R10

	MOVQ	(80)(REG_P2), R15
	MOVQ	P751P1_5, AX
	MULQ	R15
	ADDQ	AX, R8
	ADCQ	DX, R9
	ADCQ	$0, R10
	ADDQ	(120)(REG_P1), R8
	MOVQ	R8, (24)(REG_P2)		// Z3
	ADCQ	$0, R9
	ADCQ	$0, R10

	XORQ	R8, R8
	MOVQ	P751P1_11, AX
	MULQ	CX
	ADDQ	AX, R9
	ADCQ	DX, R10
	ADCQ	$0, R8

	MOVQ	P751P1_10, AX
	MULQ	R11
	ADDQ	AX, R9
	ADCQ	DX, R10
	ADCQ	$0, R8

	MOVQ	P751P1_9, AX
	MULQ	R12
	ADDQ	AX, R9
	ADCQ	DX, R10
	ADCQ	$0, R8

	MOVQ	P751P1_8, AX
	MULQ	R13
	ADDQ	AX, R9
	ADCQ	DX, R10
	ADCQ	$0, R8

	MOVQ	P751P1_7, AX
	MULQ	R14
	ADDQ	AX, R9
	ADCQ	DX, R10
	ADCQ	$0, R8

	MOVQ	P751P1_6, AX
	MULQ	R15
	ADDQ	AX, R9
	ADCQ	DX, R10
	ADCQ	$0, R8

	MOVQ	(88)(REG_P2), CX
	MOVQ	P751P1_5, AX
	MULQ	CX
	ADDQ	AX, R9
	ADCQ	DX, R10
	ADCQ	$0, R8
	ADDQ	(128)(REG_P1), R9
	MOVQ	R9, (32)(REG_P2)		// Z4
	ADCQ	$0, R10
	ADCQ	$0, R8

	XORQ	R9, R9
	MOVQ	P751P1_11, AX
	MULQ	R11
	ADDQ	AX, R10
	ADCQ	DX, R8
	ADCQ	$0, R9

	MOVQ	P751P1_10, AX
	MULQ	R12
	ADDQ	AX, R10
	ADCQ	DX, R8
	ADCQ	$0, R9

	MOVQ	P751P1_9, AX
	MULQ	R13
	ADDQ	AX, R10
	ADCQ	DX, R8
	ADCQ	$0, R9

	MOVQ	P751P1_8, AX
	MULQ	R14
	ADDQ	AX, R10
	ADCQ	DX, R8
	ADCQ	$0, R9

	MOVQ	P751P1_7, AX
	MULQ	R15
	ADDQ	AX, R10
	ADCQ	DX, R8
	ADCQ	$0, R9

	MOVQ	P751P1_6, AX
	MULQ	CX
	ADDQ	AX, R10
	ADCQ	DX, R8
	ADCQ	$0, R9
	ADDQ	(136)(REG_P1), R10
	MOVQ	R10, (40)(REG_P2)		// Z5
	ADCQ	$0, R8
	ADCQ	$0, R9

	XORQ	R10, R10
	MOVQ	P751P1_11, AX
	MULQ	R12
	ADDQ	AX, R8
	ADCQ	DX, R9
	ADCQ	$0, R10

	MOVQ	P751P1_10, AX
	MULQ	R13
	ADDQ	AX, R8
	ADCQ	DX, R9
	ADCQ	$0, R10

	MOVQ	P751P1_9, AX
	MULQ	R14
	ADDQ	AX, R8
	ADCQ	DX, R9
	ADCQ	$0, R10

	MOVQ	P751P1_8, AX
	MULQ	R15
	ADDQ	AX, R8
	ADCQ	DX, R9
	ADCQ	$0, R10

	MOVQ	P751P1_7, AX
	MULQ	CX
	ADDQ	AX, R8
	ADCQ	DX, R9
	ADCQ	$0, R10
	ADDQ	(144)(REG_P1), R8
	MOVQ	R8, (48)(REG_P2)		// Z6
	ADCQ	$0, R9
	ADCQ	$0, R10

	XORQ	R8, R8
	MOVQ	P751P1_11, AX
	MULQ	R13
	ADDQ	AX, R9
	ADCQ	DX, R10
	ADCQ	$0, R8

	MOVQ	P751P1_10, AX
	MULQ	R14
	ADDQ	AX, R9
	ADCQ	DX, R10
	ADCQ	$0, R8

	MOVQ	P751P1_9, AX
	MULQ	R15
	ADDQ	AX, R9
	ADCQ	DX, R10
	ADCQ	$0, R8

	MOVQ	P751P1_8, AX
	MULQ	CX
	ADDQ	AX, R9
	ADCQ	DX, R10
	ADCQ	$0, R8
	ADDQ	(152)(REG_P1), R9
	MOVQ	R9, (56)(REG_P2)		// Z7
	ADCQ	$0, R10
	ADCQ	$0, R8

	XORQ	R9, R9
	MOVQ	P751P1_11, AX
	MULQ	R14
	ADDQ	AX, R10
	ADCQ	DX, R8
	ADCQ	$0, R9

	MOVQ	P751P1_10, AX
	MULQ	R15
	ADDQ	AX, R10
	ADCQ	DX, R8
	ADCQ	$0, R9

	MOVQ	P751P1_9, AX
	MULQ	CX
	ADDQ	AX, R10
	ADCQ	DX, R8
	ADCQ	$0, R9
	ADDQ	(160)(REG_P1), R10
	MOVQ	R10, (64)(REG_P2)		// Z8
	ADCQ	$0, R8
	ADCQ	$0, R9

	XORQ	R10, R10
	MOVQ	P751P1_11, AX
	MULQ	R15
	ADDQ	AX, R8
	ADCQ	DX, R9
	ADCQ	$0, R10

	MOVQ	P751P1_10, AX
	MULQ	CX
	ADDQ	AX, R8
	ADCQ	DX, R9
	ADCQ	$0, R10
	ADDQ	(168)(REG_P1), R8		// Z9
	MOVQ	R8, (72)(REG_P2)		// Z9
	ADCQ	$0, R9
	ADCQ	$0, R10

	MOVQ	P751P1_11, AX
	MULQ	CX
	ADDQ	AX, R9
	ADCQ	DX, R10
	ADDQ	(176)(REG_P1), R9		// Z10
	MOVQ	R9, (80)(REG_P2)		// Z10
	ADCQ	$0, R10
	ADDQ	(184)(REG_P1), R10		// Z11
	MOVQ	R10, (88)(REG_P2)		// Z11

	RET

TEXT ·fp751AddLazy(SB), NOSPLIT, $0-24

	MOVQ z+0(FP), REG_P3
	MOVQ x+8(FP), REG_P1
	MOVQ y+16(FP), REG_P2

	MOVQ	(REG_P1), R8
	MOVQ	(8)(REG_P1), R9
	MOVQ	(16)(REG_P1), R10
	MOVQ	(24)(REG_P1), R11
	MOVQ	(32)(REG_P1), R12
	MOVQ	(40)(REG_P1), R13
	MOVQ	(48)(REG_P1), R14
	MOVQ	(56)(REG_P1), R15
	MOVQ	(64)(REG_P1), AX
	MOVQ	(72)(REG_P1), BX
	MOVQ	(80)(REG_P1), CX
	MOVQ	(88)(REG_P1), DI

	ADDQ	(REG_P2), R8
	ADCQ	(8)(REG_P2), R9
	ADCQ	(16)(REG_P2), R10
	ADCQ	(24)(REG_P2), R11
	ADCQ	(32)(REG_P2), R12
	ADCQ	(40)(REG_P2), R13
	ADCQ	(48)(REG_P2), R14
	ADCQ	(56)(REG_P2), R15
	ADCQ	(64)(REG_P2), AX
	ADCQ	(72)(REG_P2), BX
	ADCQ	(80)(REG_P2), CX
	ADCQ	(88)(REG_P2), DI

	MOVQ	R8, (REG_P3)
	MOVQ	R9, (8)(REG_P3)
	MOVQ	R10, (16)(REG_P3)
	MOVQ	R11, (24)(REG_P3)
	MOVQ	R12, (32)(REG_P3)
	MOVQ	R13, (40)(REG_P3)
	MOVQ	R14, (48)(REG_P3)
	MOVQ	R15, (56)(REG_P3)
	MOVQ	AX, (64)(REG_P3)
	MOVQ	BX, (72)(REG_P3)
	MOVQ	CX, (80)(REG_P3)
	MOVQ	DI, (88)(REG_P3)

	RET

TEXT ·fp751X2AddLazy(SB), NOSPLIT, $0-24

	MOVQ z+0(FP), REG_P3
	MOVQ x+8(FP), REG_P1
	MOVQ y+16(FP), REG_P2

	MOVQ	(REG_P1), R8
	MOVQ	(8)(REG_P1), R9
	MOVQ	(16)(REG_P1), R10
	MOVQ	(24)(REG_P1), R11
	MOVQ	(32)(REG_P1), R12
	MOVQ	(40)(REG_P1), R13
	MOVQ	(48)(REG_P1), R14
	MOVQ	(56)(REG_P1), R15
	MOVQ	(64)(REG_P1), AX
	MOVQ	(72)(REG_P1), BX
	MOVQ	(80)(REG_P1), CX

	ADDQ	(REG_P2), R8
	ADCQ	(8)(REG_P2), R9
	ADCQ	(16)(REG_P2), R10
	ADCQ	(24)(REG_P2), R11
	ADCQ	(32)(REG_P2), R12
	ADCQ	(40)(REG_P2), R13
	ADCQ	(48)(REG_P2), R14
	ADCQ	(56)(REG_P2), R15
	ADCQ	(64)(REG_P2), AX
	ADCQ	(72)(REG_P2), BX
	ADCQ	(80)(REG_P2), CX

	MOVQ	R8, (REG_P3)
	MOVQ	R9, (8)(REG_P3)
	MOVQ	R10, (16)(REG_P3)
	MOVQ	R11, (24)(REG_P3)
	MOVQ	R12, (32)(REG_P3)
	MOVQ	R13, (40)(REG_P3)
	MOVQ	R14, (48)(REG_P3)
	MOVQ	R15, (56)(REG_P3)
	MOVQ	AX, (64)(REG_P3)
	MOVQ	BX, (72)(REG_P3)
	MOVQ	CX, (80)(REG_P3)
	MOVQ	(88)(REG_P1), AX
	ADCQ	(88)(REG_P2), AX
	MOVQ	AX, (88)(REG_P3)

	MOVQ	(96)(REG_P1), R8
	MOVQ	(104)(REG_P1), R9
	MOVQ	(112)(REG_P1), R10
	MOVQ	(120)(REG_P1), R11
	MOVQ	(128)(REG_P1), R12
	MOVQ	(136)(REG_P1), R13
	MOVQ	(144)(REG_P1), R14
	MOVQ	(152)(REG_P1), R15
	MOVQ	(160)(REG_P1), AX
	MOVQ	(168)(REG_P1), BX
	MOVQ	(176)(REG_P1), CX
	MOVQ	(184)(REG_P1), DI

	ADCQ	(96)(REG_P2), R8
	ADCQ	(104)(REG_P2), R9
	ADCQ	(112)(REG_P2), R10
	ADCQ	(120)(REG_P2), R11
	ADCQ	(128)(REG_P2), R12
	ADCQ	(136)(REG_P2), R13
	ADCQ	(144)(REG_P2), R14
	ADCQ	(152)(REG_P2), R15
	ADCQ	(160)(REG_P2), AX
	ADCQ	(168)(REG_P2), BX
	ADCQ	(176)(REG_P2), CX
	ADCQ	(184)(REG_P2), DI

	MOVQ	R8, (96)(REG_P3)
	MOVQ	R9, (104)(REG_P3)
	MOVQ	R10, (112)(REG_P3)
	MOVQ	R11, (120)(REG_P3)
	MOVQ	R12, (128)(REG_P3)
	MOVQ	R13, (136)(REG_P3)
	MOVQ	R14, (144)(REG_P3)
	MOVQ	R15, (152)(REG_P3)
	MOVQ	AX, (160)(REG_P3)
	MOVQ	BX, (168)(REG_P3)
	MOVQ	CX, (176)(REG_P3)
	MOVQ	DI, (184)(REG_P3)

	RET


TEXT ·fp751X2SubLazy(SB), NOSPLIT, $0-24

	MOVQ z+0(FP), REG_P3
	MOVQ x+8(FP), REG_P1
	MOVQ y+16(FP), REG_P2

	MOVQ	(REG_P1), R8
	MOVQ	(8)(REG_P1), R9
	MOVQ	(16)(REG_P1), R10
	MOVQ	(24)(REG_P1), R11
	MOVQ	(32)(REG_P1), R12
	MOVQ	(40)(REG_P1), R13
	MOVQ	(48)(REG_P1), R14
	MOVQ	(56)(REG_P1), R15
	MOVQ	(64)(REG_P1), AX
	MOVQ	(72)(REG_P1), BX
	MOVQ	(80)(REG_P1), CX

	SUBQ	(REG_P2), R8
	SBBQ	(8)(REG_P2), R9
	SBBQ	(16)(REG_P2), R10
	SBBQ	(24)(REG_P2), R11
	SBBQ	(32)(REG_P2), R12
	SBBQ	(40)(REG_P2), R13
	SBBQ	(48)(REG_P2), R14
	SBBQ	(56)(REG_P2), R15
	SBBQ	(64)(REG_P2), AX
	SBBQ	(72)(REG_P2), BX
	SBBQ	(80)(REG_P2), CX

	MOVQ	R8, (REG_P3)
	MOVQ	R9, (8)(REG_P3)
	MOVQ	R10, (16)(REG_P3)
	MOVQ	R11, (24)(REG_P3)
	MOVQ	R12, (32)(REG_P3)
	MOVQ	R13, (40)(REG_P3)
	MOVQ	R14, (48)(REG_P3)
	MOVQ	R15, (56)(REG_P3)
	MOVQ	AX, (64)(REG_P3)
	MOVQ	BX, (72)(REG_P3)
	MOVQ	CX, (80)(REG_P3)
	MOVQ	(88)(REG_P1), AX
	SBBQ	(88)(REG_P2), AX
	MOVQ	AX, (88)(REG_P3)

	MOVQ	(96)(REG_P1), R8
	MOVQ	(104)(REG_P1), R9
	MOVQ	(112)(REG_P1), R10
	MOVQ	(120)(REG_P1), R11
	MOVQ	(128)(REG_P1), R12
	MOVQ	(136)(REG_P1), R13
	MOVQ	(144)(REG_P1), R14
	MOVQ	(152)(REG_P1), R15
	MOVQ	(160)(REG_P1), AX
	MOVQ	(168)(REG_P1), BX
	MOVQ	(176)(REG_P1), CX
	MOVQ	(184)(REG_P1), DI

	SBBQ	(96)(REG_P2), R8
	SBBQ	(104)(REG_P2), R9
	SBBQ	(112)(REG_P2), R10
	SBBQ	(120)(REG_P2), R11
	SBBQ	(128)(REG_P2), R12
	SBBQ	(136)(REG_P2), R13
	SBBQ	(144)(REG_P2), R14
	SBBQ	(152)(REG_P2), R15
	SBBQ	(160)(REG_P2), AX
	SBBQ	(168)(REG_P2), BX
	SBBQ	(176)(REG_P2), CX
	SBBQ	(184)(REG_P2), DI

	MOVQ	R8, (96)(REG_P3)
	MOVQ	R9, (104)(REG_P3)
	MOVQ	R10, (112)(REG_P3)
	MOVQ	R11, (120)(REG_P3)
	MOVQ	R12, (128)(REG_P3)
	MOVQ	R13, (136)(REG_P3)
	MOVQ	R14, (144)(REG_P3)
	MOVQ	R15, (152)(REG_P3)
	MOVQ	AX, (160)(REG_P3)
	MOVQ	BX, (168)(REG_P3)
	MOVQ	CX, (176)(REG_P3)
	MOVQ	DI, (184)(REG_P3)

	// Now the carry flag is 1 if x-y < 0.  If so, add p*2^768.
	ZERO_AX_WITHOUT_CLOBBERING_FLAGS
	SBBQ	$0, AX

	// Load p into registers:
	MOVQ	P751_0, R8
	// P751_{1,2,3,4} = P751_0, so reuse R8
	MOVQ	P751_5, R9
	MOVQ	P751_6, R10
	MOVQ	P751_7, R11
	MOVQ	P751_8, R12
	MOVQ	P751_9, R13
	MOVQ	P751_10, R14
	MOVQ	P751_11, R15

	ANDQ	AX, R8
	ANDQ	AX, R9
	ANDQ	AX, R10
	ANDQ	AX, R11
	ANDQ	AX, R12
	ANDQ	AX, R13
	ANDQ	AX, R14
	ANDQ	AX, R15

	ADDQ	R8,  (96   )(REG_P3)
	ADCQ	R8,  (96+ 8)(REG_P3)
	ADCQ	R8,  (96+16)(REG_P3)
	ADCQ	R8,  (96+24)(REG_P3)
	ADCQ	R8,  (96+32)(REG_P3)
	ADCQ	R9,  (96+40)(REG_P3)
	ADCQ	R10, (96+48)(REG_P3)
	ADCQ	R11, (96+56)(REG_P3)
	ADCQ	R12, (96+64)(REG_P3)
	ADCQ	R13, (96+72)(REG_P3)
	ADCQ	R14, (96+80)(REG_P3)
	ADCQ    R15, (96+88)(REG_P3)

	RET


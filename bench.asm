format PE64 console

entry main
section ".text" code readable executable

macro struct [s] {
forward
	virtual at 0
		s s
		sizeof.#s:
	end virtual
	;
	irps reg, rax rdx rcx rbx rsi rdi rsp rbp r8 r9 r10 r11 r12 r13 r14 r15 \{
		virtual at reg
			reg\#.\#s s
		end virtual
	\}
}

struc mseq_s {
	.base	dq ?
	.size	dd ?,? ; <= 32
		rq 2
	
	.begin:	rd 32
	.end:	rd 32
	.index:	rd 32
	.min.i:	rd 32
	.min:	rb 32
}

struc csv_s {
	.raw.data	dq ?
	.raw.size	dq ?
	.mseq		dq ?
	.mseq.end	dq ?
}

struct mseq_s, csv_s

struc load_csv_m {
	.:
	virtual at rsp
		.args:	rq 8
		
		.file	dq ?
		.mseq.aprox.size	dq ?
		.mseq.aprox.count	dq ?
		.mem.to.free	dq ?
			rq 3
		.locals.size = $ - $$
		.regs	rq 3 + 1
		.rip	dq ?
		.prms:
		.csv	dq ? ; csv_s *rcx
		.name	dq ? ; const char *rdx
	end virtual
	push	rbp rbx rsi rdi
	sub	rsp,.locals.size
	
	mov	[.csv],rcx
	mov	[.name],rdx
	mov	rcx,rdx
	mov	rdx,access.read
	call	[fopen]
	mov	[.file],rax
	mov	rcx,rax
	xor	edx,edx
	mov	r8,2
	call	[fseek]
	mov	rcx,[.file]
	call	[ftell]
	mov	rbx,[.csv]
	mov	[rbx.csv_s.raw.size],rax
	
	xor	rdx,rdx
	mov	rcx,64 * 32	; bad bigbugex
	div	rcx
	add	rax,1
	mov	[.mseq.aprox.count],rax
	mov	rcx,sizeof.mseq_s
	mul	rcx
	mov	[.mseq.aprox.size],rax
	
	mov	rcx,[rbx.csv_s.raw.size]
	add	rcx,32
	call	[malloc]
	add	rax,31
	and	rax,-32
	mov	[rbx.csv_s.raw.data],rax
	
	mov	rcx,[.file]
	xor	rdx,rdx
	mov	r8,0
	call	[fseek]
	
	mov	rcx,[rbx.csv_s.raw.data]
	mov	rdx,1
	mov	r8,[rbx.csv_s.raw.size]
	mov	r9,[.file]
	call	[fread]
	
	mov	rcx,[.file]
	call	[fclose]
	
	mov	rcx,[.mseq.aprox.size]
	add	rcx,32
	call	[malloc]
	add	rax,31
	and	rax,-32
	mov	[rbx.csv_s.mseq],rax
	mov	rsi,rax
	cld
	mov	rdi,rax
	xor	rax,rax
	mov	rcx,[.mseq.aprox.size]
	rep	stosb
	
	vpbroadcastb	ymm0,[const_C]
	vpbroadcastb	ymm1,[const_G]
	vpbroadcastb	ymm2,[const_T]
	vpbroadcastb	ymm3,[const_A]
	xor	r8,r8
	mov	rbp,[rbx.csv_s.raw.data]
	mov	r9,[rbx.csv_s.raw.size]
	mov	rdi,rbp
	add	r9,rbp
	mov	[rsi.mseq_s.base],rbp
	xor	r10,r10
	
	macro .test \{
		vmovdqa	ymm4,[rdi]
		vpcmpeqb	ymm5,ymm0,ymm4
		vpcmpeqb	ymm6,ymm1,ymm4
		vpor	ymm5,ymm5,ymm6
		vpcmpeqb	ymm6,ymm2,ymm4
		vpcmpeqb	ymm7,ymm3,ymm4
		vpor	ymm5,ymm5,ymm6
		vpor	ymm5,ymm5,ymm7
		vpmovmskb	eax,ymm5
		add	rdi,0x20
	\}
	
	.a0:
	cmp	rdi,r9
	jae	.brk
	.test
	.a2:
	tzcnt	ecx,eax
	cmp	ecx,32
	je	.a0
	lea	rdx,[rdi + rcx - 0x20]
	sub	rdx,rbp
	mov	[rsi.mseq_s.begin + r8 * 4],edx
	mov	edx,1
	shl	edx,cl
	add	eax,edx
	jnc	.a1
	
	@@:
	.test
	add	eax,1
	jc	@b
	
	.a1:
	tzcnt	ecx,eax
	lea	edx,[eax - 1]
	and	eax,edx
	lea	rdx,[rdi + rcx - 0x20]
	mov	byte[rdx],0
	sub	rdx,rbp
	mov	[rsi.mseq_s.end + r8 * 4],edx
	mov	[rsi.mseq_s.index + r8 * 4],r10d
	mov	byte[rsi.mseq_s.min + r8],-1
	add	r10,1
	add	r8,1
	cmp	r8,32
	jb	.a2
	
	mov	[rsi.mseq_s.size],r8d
	xor	r8,r8
	lea	rbp,[rdi - 0x20]
	add	rsi,sizeof.mseq_s
	mov	[rsi.mseq_s.base],rbp
	jmp	.a2
	
	.brk:
	mov	[rsi.mseq_s.size],r8d
	lea	rax,[rsi + sizeof.mseq_s]
	test	r8,r8
	cmovnz	rsi,rax
	mov	[rbx.csv_s.mseq.end],rsi
	
	add	rsp,.locals.size
	pop	rdi rsi rbx rbp
	ret
} load_csv load_csv_m

struc levenstein_avx2_m {
	.:
	virtual at rsp
		.args:	rq 8
		
		.offset	dq ?
			rq 3
		.mincol:	rq 4
		.col:	rb 256 * 32
			rq 0
		.locals.size = $ - $$
		.regs	rq 7
		.rip	dq ?
		.prms:
		
		.gpa	dq ? ;mseq_s *rcx;
		.gpb	dq ? ;mseq_s *rdx;
		.buf	dq ? ;char[255][32] r8
		.maxsize:	dq ? ;unsigned r9
	end virtual
	push	rsi rdi rbx rbp r12 r13 r14
	sub	rsp,.locals.size
	
	mov	[.gpa],rcx
	mov	[.gpb],rdx
	mov	[.buf],r8
	mov	[.maxsize],r9
	
	vpcmpeqb	ymm15,ymm15,ymm15
	mov	rbp,[.gpb]
	xor	r8,r8
	
	.a1:
	mov	ecx,[.maxsize]
	shl	rcx,5
	mov	r12,[.buf]
	
	mov	esi,[rbp.mseq_s.begin + r8 * 4]
	mov	edi,[rbp.mseq_s.end + r8 * 4]
	add	rsi,[rbp.mseq_s.base]
	add	rdi,[rbp.mseq_s.base]
	
	@@:
	vpbroadcastb	ymm1,[rsi]
	vpcmpeqb	ymm1,ymm1,[r12]
	vpmovmskb	eax,ymm1
	add	rsi,1
	add	r12,32
	sub	rcx,32
	add	eax,1
	jc	@b
	
	sub	rsi,1
	sub	r12,32
	add	rcx,32
	mov	rax,r12
	sub	rax,[.buf]
	mov	[.offset],rax
	vpxor	ymm0,ymm0,ymm0
	mov	rbx,0x20
	
	@@:
	vpsubb	ymm0,ymm0,ymm15
	vmovdqa	[.col + rbx],ymm0
	add	rbx,0x20
	cmp	rbx,rcx
	jbe	@b
	
	mov	rbx,0x20
	vpxor	ymm0,ymm0,ymm0
	vmovdqa	ymm1,ymm0
	vpsubb	ymm0,ymm0,ymm15	; x = 1
	vpbroadcastb	ymm2,[rsi]
	vmovdqa	ymm7,ymm0
	jmp	.a0
	
	align	0x40
	.a0:
	vpcmpeqb	ymm3,ymm2,[r12 + rbx - 0x20]
	vmovdqa	ymm5,[.col + rbx]
	vpsubb	ymm6,ymm5,ymm15	; ymm6 = col[y] + 1
	vmovdqa	[.col + rbx - 0x20],ymm7	; col[y - 1] = prevcol
	add	rbx,0x20
	vpsubb	ymm1,ymm1,ymm15
	vpsubb	ymm7,ymm7,ymm15	; ymm7 = col[y - 1] + 1
	vpaddb	ymm1,ymm1,ymm3	; ymm1 = lastdiag + ( sa[x - 1] != sb[y - 1] )
	vpminub	ymm7,ymm6,ymm7
	vpminub	ymm7,ymm7,ymm1
	vmovdqa	ymm1,ymm5	; ymm1 = olddiag
	cmp	rbx,rcx
	jbe	.a0
	
	vmovdqa	[.col + rbx - 0x20],ymm7
	mov	rbx,0x20
	add	rsi,1
	vmovdqa	ymm1,ymm0
	vpsubb	ymm0,ymm0,ymm15
	vpbroadcastb	ymm2,[rsi]
	vmovdqa	ymm7,ymm0
	cmp	rsi,rdi
	jb	.a0
	
	mov	rsi,[.gpa]
	xor	r10,r10
	mov	r11b,[rbp.mseq_s.min + r8]
	mov	r13d,[rsi.mseq_s.size]
	mov	r14,[.offset]
	
	@@:
	mov	r9d,[rsi.mseq_s.end + r10 * 4]
	sub	r9d,[rsi.mseq_s.begin + r10 * 4]
	shl	r9,5
	add	r9,r10
	sub	r9,r14
	mov	al,[.col + r9]
	mov	dl,[rsi.mseq_s.min + r10]
	cmp	dl,al
	cmova	edx,eax
	mov	[rsi.mseq_s.min + r10],dl
	add	r10,1
	cmp	r11b,al
	cmova	r11d,eax
	cmp	r10,r13
	jb	@b
	
	mov	[rbp.mseq_s.min + r8],r11b
	
	add	r8,1
	cmp	r8d,[rbp.mseq_s.size]
	jb	.a1
	
	.break:
	add	rsp,.locals.size
	pop	r14 r13 r12 rbp rbx rdi rsi
	ret
} levenstein_32x32 levenstein_avx2_m

struc maxsize_and_interleave_m {
	.:
	virtual at rsp
		.args	rq 8
		
			rq 1
		.locals.size = $ - $$
		.regs	rq 2
		.rip	dq ?
		.prms:
		.block	dq ?	; char[255][32] rcx
		.gp	dq ?	; mseq_s *rdx
	end virtual
	push	rsi rdi
	sub	rsp,.locals.size
	vmovdqa	ymm0,[rdx.mseq_s.end]
	vmovdqa	ymm1,[rdx.mseq_s.end + 0x20]
	vmovdqa	ymm2,[rdx.mseq_s.end + 0x40]
	vmovdqa	ymm3,[rdx.mseq_s.end + 0x60]
	vpsubd	ymm0,ymm0,[rdx.mseq_s.begin]
	vpsubd	ymm1,ymm1,[rdx.mseq_s.begin + 0x20]
	vpsubd	ymm2,ymm2,[rdx.mseq_s.begin + 0x40]
	vpsubd	ymm3,ymm3,[rdx.mseq_s.begin + 0x60]
	vpmaxsd	ymm0,ymm0,ymm1
	vpmaxsd	ymm2,ymm2,ymm3
	vpmaxsd	ymm0,ymm0,ymm2
	vpermq	ymm1,ymm0,01001110b
	vpmaxsd	xmm0,xmm0,xmm1
	vpshufd	xmm1,xmm0,01001110b
	vpmaxsd	xmm0,xmm0,xmm1
	vpshufd	xmm1,xmm0,00111001b
	vpmaxsd	xmm0,xmm0,xmm1
	movd	dword[.args + 4 * 8],xmm0
	mov	[.block],rcx
	mov	[.gp],rdx
	
	lea	rsi,[rdx.mseq_s.begin]
	mov	rdi,rcx
	mov	rax,[rdx.mseq_s.base]
	mov	r8d,dword[.args + 4 * 8]
	
	vpbroadcastd	ymm14,[const4]
	movdqa	xmm0,[rsi + 0]
	movdqa	xmm1,[rsi + 0x10]
	movdqa	xmm2,[rsi + 0x20]
	movdqa	xmm3,[rsi + 0x30]
	vinserti128	ymm0,ymm0,[rsi + 0x40],1
	vinserti128	ymm1,ymm1,[rsi + 0x50],1
	vinserti128	ymm2,ymm2,[rsi + 0x60],1
	vinserti128	ymm3,ymm3,[rsi + 0x70],1
	xor	edx,edx
	
	@@:
	vpcmpeqb	ymm15,ymm15,ymm15
	vpgatherdd	ymm4,[rax + ymm0],ymm15
	vpaddd	ymm0,ymm0,ymm14
	vpcmpeqb	ymm15,ymm15,ymm15
	vpgatherdd	ymm5,[rax + ymm1],ymm15
	vpaddd	ymm1,ymm1,ymm14
	vpcmpeqb	ymm15,ymm15,ymm15
	vpgatherdd	ymm6,[rax + ymm2],ymm15
	vpaddd	ymm2,ymm2,ymm14
	vpcmpeqb	ymm15,ymm15,ymm15
	vpgatherdd	ymm7,[rax + ymm3],ymm15
	vpaddd	ymm3,ymm3,ymm14
	add	edx,4
	
	vpunpcklbw	ymm8,ymm4,ymm5
	vpunpckhbw	ymm9,ymm4,ymm5
	vpunpcklbw	ymm10,ymm6,ymm7
	vpunpckhbw	ymm11,ymm6,ymm7
	
	vpunpcklwd	ymm4,ymm8,ymm10
	vpunpckhwd	ymm5,ymm8,ymm10
	vpunpcklwd	ymm6,ymm9,ymm11
	vpunpckhwd	ymm7,ymm9,ymm11
	
	vpunpcklbw	ymm8,ymm4,ymm5
	vpunpckhbw	ymm9,ymm4,ymm5
	vpunpcklbw	ymm10,ymm6,ymm7
	vpunpckhbw	ymm11,ymm6,ymm7
	
	vpunpcklwd	ymm4,ymm8,ymm10
	vpunpckhwd	ymm5,ymm8,ymm10
	vpunpcklwd	ymm6,ymm9,ymm11
	vpunpckhwd	ymm7,ymm9,ymm11
	
	vmovdqa	[rdi + 0x00],ymm4
	vmovdqa	[rdi + 0x20],ymm5
	vmovdqa	[rdi + 0x40],ymm6
	vmovdqa	[rdi + 0x60],ymm7
	
	add	rdi,0x80
	cmp	edx,r8d
	jb	@b
	
	mov	eax,dword[.args + 4 * 8]
	add	rsp,.locals.size
	pop	rdi rsi
	ret
} maxsize_and_interleave maxsize_and_interleave_m

struc main_m {
	.:
	virtual at rsp
		.args	rq 8
		
		.set.A	csv_s
		.set.B	csv_s
		.buf:	rb 255 * 0x20
			rq 2
		.locals.size = $ - $$
		.regs	rq 5
		.rip	dq ?
	end virtual
	and	rsp,-32
	sub	rsp,8
	push	rbp rbx rsi rdi r12
	sub	rsp,.locals.size
	
	mov	rcx,msg
	call	[printf]
	
	lea	rcx,[.set.A]
	mov	rdx,name.A
	call	load_csv
	
	lea	rcx,[.set.B]
	mov	rdx,name.B
	call	load_csv
	
	xor	edx,edx
	mov	rsi,[.set.A.mseq]
	mov	rdi,[.set.A.mseq.end]
	@@:
	add	edx,[rsi.mseq_s.size]
	add	rsi,sizeof.mseq_s
	cmp	rsi,rdi
	jb	@b
	mov	rcx,fmt2
	call	[printf]
	
	call	[clock]
	mov	[.args + 6 * 8],rax
	
	mov	rsi,[.set.A.mseq]
	mov	rdi,[.set.B.mseq]
	
	lea	rcx,[.buf]
	mov	rdx,rsi
	call	maxsize_and_interleave
	mov	r12,rax
	
	@@:
	mov	rcx,rsi
	mov	rdx,rdi
	lea	r8,[.buf]
	mov	r9,r12
	call	levenstein_32x32
	add	rdi,sizeof.mseq_s
	cmp	rdi,[.set.B.mseq.end]
	jb	@b
	
	mov	rdi,[.set.B.mseq]
	add	rsi,sizeof.mseq_s
	cmp	rsi,[.set.A.mseq.end]
	jae	@f
	
	lea	rcx,[.buf]
	mov	rdx,rsi
	call	maxsize_and_interleave
	mov	r12,rax
	jmp	@b
	
	@@:
	call	[clock]
	sub	eax,dword[.args + 6 * 8]
	mov	rbp,rax
	
	mov	rsi,[.set.B.mseq]
	xor	rbx,rbx
	xor	rdi,rdi
	xor	r12,r12
	
	@@:
	mov	rcx,fmt.result
	mov	edx,edi
	movzx	r8,byte[rsi.mseq_s.min + rbx]
	call	[printf]
	add	rbx,1
	add	rdi,1
	cmp	ebx,[rsi.mseq_s.size]
	jb	@b
	
	xor	rbx,rbx
	add	r12d,[rsi.mseq_s.size]
	add	rsi,sizeof.mseq_s
	cmp	rsi,[.set.B.mseq.end]
	jb	@b
	
	mov	eax,ebp
	xor	edx,edx
	div	r12d
	mov	rcx,fmt.time
	mov	edx,eax
	call	[printf]
	
	mov	rcx,fmt.total
	mov	edx,ebp
	call	[printf]
	
	xor	rcx,rcx
	call	[exit]
	
	add	rsp,.locals.size
	pop	r12 rdi rsi rbx rbp
	ret
} main main_m

section ".data" data writeable

struc data_set_s [s]{
common	align 0x20
	.:
forward
	local offset
	dd offset - .str
common
	.str:
forward
	offset db s
}
block data_set_s\
	"aaaaaaaa", "01234567", "cccccccc", "dddddddd",\ ;
	"eeeeeeee", "ffffffff", "gggggggg", "hhhhhhhh",\ ;
	"iiiiiiii", "jjjjjjjj", "kkkkkkkk", "llllllll",\ ;
	"mmmmmmmm", "nnnnnnnn", "oooooooo", "pppppppp",\ ;
	"qqqqqqqq", "rrrrrrrr", "ssssssss", "tttttttt",\ ;
	"uuuuuuuu", "vvvvvvvv", "wwwwwwww", "xxxxxxxx",\ ;
	"yyyyyyyy", "zzzzzzzz", "AAAAAAAA", "BBBBBBBB",\ ;
	"CCCCCCCC", "DDDDDDDD", "EEEEEEEE", "FFFFFFFF"

constd_0123:	dd 0,1,2,3, 4,5,6,7
const_arr	dd 0,8,16,24
const4	dd 4
constFF	dd 0x000000FF
const_C db 'C'
const_G db 'G'
const_T db 'T'
const_A db 'A'
fmt0 db "%.8s",13,10,0
fmt1 db "%.32s",13,10,0
fmt2 db "%u",13,10,0
fmt3 db "%p",13,10,0
fmt.result	db "%u:	dist %u",13,10,0
fmt.time	db "%u ms per string",13,10,0
fmt.total	db "Total time %u ms",13,10,0
fmt.dump	db "%p %p",13,10,0
dmpm db "%.4u:%s",13,10,0
name.A db "Dataset.csv",0
name.B db "t2.csv",0
access.read db "r",0
msg db "Trump 2020",13,10,0

section ".import" import data readable
dd 0,0,0, RVA msvcrt.name, RVA msvcrt.table
dd 0,0,0, RVA kernel.name, RVA kernel.table
dd 0,0,0,0,0

align 8
msvcrt.table:
	printf dq RVA _printf
	malloc dq RVA _malloc
	free dq RVA _free
	fopen dq RVA _fopen
	fclose dq RVA _fclose
	fseek dq RVA _fseek
	ftell dq RVA _ftell
	fread dq RVA _fread
	clock dq RVA _clock
	dq 0
	
kernel.table:
	exit dq RVA _ExitProcess
	qpc dq RVA _qpc
	qpf dq RVA _qpf
	dq 0
	
msvcrt.name db "MSVCRT.DLL",0
kernel.name db "KERNEL32.DLL",0

_printf dw 0
	db "printf",0
_malloc dw 0
	db "malloc",0
_free dw 0
	db "free",0
_fopen dw 0
	db "fopen",0
_fclose dw 0
	db "fclose",0
_fseek dw 0
	db "fseek",0
_ftell dw 0
	db "ftell",0
_fread dw 0
	db "fread",0
_clock dw 0
	db "clock",0
	
_ExitProcess dw 0
	db "ExitProcess",0
_qpc dw 0
	db "QueryPerformanceCounter",0
_qpf dw 0
	db "QueryPerformanceFrequency",0


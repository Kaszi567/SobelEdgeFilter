; ============================================================
; Temat:      Wykrywanie krawedzi filtrem Sobela (C# vs ASM x64 AVX2)
; Opis:       Biblioteka asemblerowa do przetwarzania obrazow.
;             Implementacja filtru Sobela w wersji skalarnej
;             i wektorowej AVX2 oraz negatywu obrazu.
; Autor:      Julia Boszczon
; Rok/sem.:   2026/2027, semestr zimowy
; Data:       28.10.2026
; Wersje:
;   v0.1 28.10.2026 Julia B - Initial image inversion
;   v0.2 20.11.2026 Julia B - Scalar Sobel implementation
;   v0.3 20.11.2026 Julia B - AVX2 Sobel implementation
; ============================================================

.code

; ------------------------------------------------------------
; InvertAsm - Inverts a grayscale image.
; Formula: dst[i] = 255 - src[i]
;
; Input:
;   RCX = src (pointer to grayscale pixels, values 0-255)
;   RDX = dst (pointer to output buffer)
;   R8D = width (image width, range 3-16384)
;   R9D = height (image height, range 3-16384)
;
; Output:
;   dst contains inverted pixel values (0-255).
;   Buffer size: width * height bytes.
;
; Modified registers: RAX, RCX, RDX, R9, R10, YMM0, YMM1
; Modified flags: CF, ZF, SF, OF, PF, AF
; ------------------------------------------------------------

InvertAsm proc
    mov     eax, r8d                  ; RAX = width
    mov     r9d, r9d                  ; Zero-extend height
    imul    rax, r9                   ; RAX = width * height

    test    rax, rax                  ; Check if image is empty
    jz      Done                      ; Exit if no pixels remain

    vpcmpeqb ymm1, ymm1, ymm1        ; Fill YMM1 with 32 bytes of 255

VecLoop:
    cmp     rax, 32                  ; Check if at least 32 bytes remain
    jb      ScalarTail               ; Process remaining bytes individually

    vmovdqu ymm0, ymmword ptr [rcx]  ; Load 32 source pixels
    vpsubb  ymm0, ymm1, ymm0         ; Invert 32 pixels simultaneously
    vmovdqu ymmword ptr [rdx], ymm0  ; Store 32 inverted pixels

    add     rcx, 32                  ; Advance source pointer
    add     rdx, 32                  ; Advance destination pointer
    sub     rax, 32                  ; Decrease remaining pixel count
    jmp     VecLoop                  ; Repeat vector processing

ScalarTail:
    test    rax, rax                  ; Check if any pixels remain
    jz      Done                      ; Exit if all pixels are processed

NextByte:
    mov     r10b, 255                ; Set maximum pixel value
    sub     r10b, byte ptr [rcx]     ; Calculate 255 - src[i]
    mov     byte ptr [rdx], r10b     ; Store result in dst[i]

    inc     rcx                      ; Move to next source pixel
    inc     rdx                      ; Move to next destination pixel
    dec     rax                      ; Decrease remaining pixel count
    jnz     NextByte                 ; Repeat until all pixels are processed

Done:
    vzeroupper                       ; Clear upper YMM register halves
    ret                              ; Return to the caller
InvertAsm endp


; ------------------------------------------------------------
; SobelAsm - Sobel edge detection (scalar and AVX2).
;
; Gx = (tr + 2r + br) - (tl + 2l + bl)
; Gy = (bl + 2b + br) - (tl + 2t + tr)
; G = |Gx| + |Gy|
; dst = 255 if G >= threshold, otherwise 0.
;
; AVX2 processes 16 pixels per iteration.
; Remaining pixels are processed by the scalar loop.
;
; Input:
;   RCX       = src (Gray8 input image)
;   RDX       = dst (separate output buffer)
;   R8D       = width (3..16384)
;   R9D       = height (3..16384)
;   [RSP+40]  = threshold (0..2040)
;
; Output:
;   dst contains 0 or 255, with a black border.
;   Buffer size: width * height bytes.
;
; Modified registers: RAX, RCX, RDX, R8-R11, YMM0-YMM5
; Preserved registers: RBX, RSI, RDI, R12-R15
; Modified flags: CF, ZF, SF, OF, PF, AF
; ------------------------------------------------------------

SobelAsm proc
    mov     r10d, dword ptr [rsp+40]  ; Read threshold before pushing registers

    push    rbx                       ; Preserve nonvolatile registers
    push    rsi
    push    rdi
    push    r12
    push    r13
    push    r14
    push    r15

    mov     r8d, r8d                  ; Zero-extend width
    mov     r9d, r9d                  ; Zero-extend height

    cmp     r8, 3                     ; Check minimum width
    jb      SbExit                    ; Exit if width < 3

    cmp     r9, 3                     ; Check minimum height
    jb      SbExit                    ; Exit if height < 3

    ; --------------------------------------------------------
    ; Clear the entire output buffer using AVX2.
    ; --------------------------------------------------------

    mov     rax, r8                   ; RAX = width
    imul    rax, r9                   ; RAX = total number of pixels
    mov     rdi, rdx                  ; RDI = destination pointer

    vpxor   ymm0, ymm0, ymm0         ; YMM0 = 32 zero bytes

SbZeroVec:
    cmp     rax, 32                   ; Check if at least 32 bytes remain
    jb      SbZeroTail                ; Process the remaining bytes

    vmovdqu ymmword ptr [rdi], ymm0   ; Clear 32 bytes simultaneously
    add     rdi, 32                   ; Advance destination pointer
    sub     rax, 32                   ; Decrease remaining byte count
    jmp     SbZeroVec                 ; Continue vector clearing

SbZeroTail:
    test    rax, rax                  ; Check if any bytes remain
    jz      SbZeroDone                ; Continue when buffer is cleared

    mov     byte ptr [rdi], 0         ; Clear one remaining byte
    inc     rdi                       ; Advance destination pointer
    dec     rax                       ; Decrease remaining byte count
    jmp     SbZeroTail                ; Repeat until complete

SbZeroDone:
    ; --------------------------------------------------------
    ; Prepare the threshold vector.
    ; Compare g > threshold - 1 to implement g >= threshold.
    ; --------------------------------------------------------

    mov     eax, r10d                 ; EAX = threshold
    dec     eax                       ; EAX = threshold - 1
    vmovd   xmm5, eax                 ; Move threshold to XMM5
    vpbroadcastw ymm5, xmm5           ; Broadcast to 16 signed words

    ; --------------------------------------------------------
    ; Initialize pointers to the first interior row.
    ; --------------------------------------------------------

    lea     rsi, [rcx + r8]           ; RSI = second source row
    lea     rdi, [rdx + r8]           ; RDI = second destination row

    mov     r11, r9                   ; R11 = height
    sub     r11, 2                    ; Process only interior rows

SbRowLoop:
    lea     r12, [rsi + 1]            ; R12 = first interior source pixel
    lea     r13, [rdi + 1]            ; R13 = first interior destination pixel

    mov     r14, r8                   ; R14 = width
    sub     r14, 2                    ; Exclude left and right borders

    ; --------------------------------------------------------
    ; AVX2 Sobel loop - process 16 pixels per iteration.
    ; --------------------------------------------------------

SbVecLoop:
    cmp     r14, 16                   ; Check if at least 16 pixels remain
    jb      SbScalarLoop              ; Use scalar loop for remaining pixels

    mov     rbx, r12                  ; RBX = current source pointer
    sub     rbx, r8                   ; RBX = top row pointer
    lea     r15, [r12 + r8]           ; R15 = bottom row pointer

    ; Calculate A = br - tl

    vpmovzxbw ymm0, xmmword ptr [r15+1] ; Load 16 bottom-right pixels
    vpmovzxbw ymm1, xmmword ptr [rbx-1] ; Load 16 top-left pixels
    vpsubw    ymm0, ymm0, ymm1         ; YMM0 = A = br - tl

    ; Calculate B = tr - bl

    vpmovzxbw ymm1, xmmword ptr [rbx+1] ; Load 16 top-right pixels
    vpmovzxbw ymm2, xmmword ptr [r15-1] ; Load 16 bottom-left pixels
    vpsubw    ymm1, ymm1, ymm2         ; YMM1 = B = tr - bl

    ; Calculate 2 * (r - l)

    vpmovzxbw ymm2, xmmword ptr [r12+1] ; Load 16 right pixels
    vpmovzxbw ymm3, xmmword ptr [r12-1] ; Load 16 left pixels
    vpsubw    ymm2, ymm2, ymm3         ; YMM2 = r - l
    vpaddw    ymm2, ymm2, ymm2         ; YMM2 = 2 * (r - l)

    ; Calculate 2 * (b - t)

    vpmovzxbw ymm3, xmmword ptr [r15] ; Load 16 bottom pixels
    vpmovzxbw ymm4, xmmword ptr [rbx] ; Load 16 top pixels
    vpsubw    ymm3, ymm3, ymm4         ; YMM3 = b - t
    vpaddw    ymm3, ymm3, ymm3         ; YMM3 = 2 * (b - t)

    ; Calculate Gx = A + B + 2 * (r - l)

    vpaddw    ymm4, ymm0, ymm1         ; YMM4 = A + B
    vpaddw    ymm4, ymm4, ymm2         ; YMM4 = Gx
    vpabsw    ymm4, ymm4              ; YMM4 = |Gx|

    ; Calculate Gy = A - B + 2 * (b - t)

    vpsubw    ymm0, ymm0, ymm1         ; YMM0 = A - B
    vpaddw    ymm0, ymm0, ymm3         ; YMM0 = Gy
    vpabsw    ymm0, ymm0              ; YMM0 = |Gy|

    ; Calculate G = |Gx| + |Gy|

    vpaddw    ymm0, ymm0, ymm4         ; YMM0 = gradient magnitude

    ; Apply the threshold and store 16 output pixels

    vpcmpgtw  ymm0, ymm0, ymm5         ; FFFF if G >= threshold, else 0
    vextracti128 xmm1, ymm0, 1         ; Extract upper 8 words
    vpacksswb xmm0, xmm0, xmm1         ; Pack 16 words into 16 bytes
    vmovdqu   xmmword ptr [r13], xmm0  ; Store 16 binary output pixels

    add     r12, 16                   ; Advance source pointer by 16
    add     r13, 16                   ; Advance destination pointer by 16
    sub     r14, 16                   ; Decrease remaining pixel count
    jmp     SbVecLoop                 ; Continue AVX2 processing

    ; --------------------------------------------------------
    ; Scalar Sobel loop - process remaining pixels.
    ; --------------------------------------------------------

SbScalarLoop:
    test    r14, r14                  ; Check if any pixels remain
    jz      SbNextRow                 ; Move to the next row if finished

    mov     rbx, r12                  ; RBX = current source pointer
    sub     rbx, r8                   ; RBX = top row pointer
    lea     r15, [r12 + r8]           ; R15 = bottom row pointer

    movzx   edx, byte ptr [rbx+1]     ; Load tr
    mov     eax, edx                  ; Initialize Gx with tr
    mov     ecx, edx                  ; Initialize Gy with tr
    neg     ecx                       ; Gy = -tr

    movzx   edx, byte ptr [rbx-1]     ; Load tl
    sub     eax, edx                  ; Gx -= tl
    sub     ecx, edx                  ; Gy -= tl

    movzx   edx, byte ptr [r15+1]     ; Load br
    add     eax, edx                  ; Gx += br
    add     ecx, edx                  ; Gy += br

    movzx   edx, byte ptr [r15-1]     ; Load bl
    sub     eax, edx                  ; Gx -= bl
    add     ecx, edx                  ; Gy += bl

    movzx   edx, byte ptr [r12+1]     ; Load r
    lea     eax, [eax + edx*2]        ; Gx += 2*r

    movzx   edx, byte ptr [r12-1]     ; Load l
    add     edx, edx                  ; EDX = 2*l
    sub     eax, edx                  ; Gx -= 2*l

    movzx   edx, byte ptr [r15]       ; Load b
    lea     ecx, [ecx + edx*2]        ; Gy += 2*b

    movzx   edx, byte ptr [rbx]       ; Load t
    add     edx, edx                  ; EDX = 2*t
    sub     ecx, edx                  ; Gy -= 2*t

    ; Calculate absolute gradient values

    mov     edx, eax                  ; Save Gx
    neg     eax                       ; EAX = -Gx
    cmovl   eax, edx                  ; EAX = |Gx|

    mov     edx, ecx                  ; Save Gy
    neg     ecx                       ; ECX = -Gy
    cmovl   ecx, edx                  ; ECX = |Gy|

    add     eax, ecx                  ; EAX = |Gx| + |Gy|

    ; Apply threshold

    xor     edx, edx                  ; Default output = 0
    cmp     eax, r10d                 ; Compare gradient with threshold
    jl      SbStore                   ; Store 0 if below threshold
    mov     dl, 255                   ; Otherwise output = 255

SbStore:
    mov     byte ptr [r13], dl        ; Store result
    inc     r12                       ; Advance source pointer
    inc     r13                       ; Advance destination pointer
    dec     r14                       ; Decrease remaining pixel count
    jmp     SbScalarLoop              ; Process next pixel

SbNextRow:
    add     rsi, r8                   ; Advance to next source row
    add     rdi, r8                   ; Advance to next destination row
    dec     r11                       ; Decrease remaining row count
    jnz     SbRowLoop                 ; Process next row

SbExit:
    vzeroupper                        ; Clear upper YMM register halves

    pop     r15                       ; Restore nonvolatile registers
    pop     r14
    pop     r13
    pop     r12
    pop     rdi
    pop     rsi
    pop     rbx

    ret                               ; Return to caller
SobelAsm endp

end

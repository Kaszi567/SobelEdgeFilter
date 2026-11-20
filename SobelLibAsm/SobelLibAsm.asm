
; ============================================================
; Temat:      Wykrywanie krawedzi filtrem Sobela (C# vs ASM x64 AVX2)
; Opis:       Biblioteka asemblerowa do przetwarzania obrazow.
;             Implementacja negatywu obrazu w skali szarosci.
; Autor:      Julia Boszczon
; Rok/sem.:   2026/2027, semestr zimowy
; Data:       28.10.2026
; Wersje:
;   v0.1 28.10.2026 Julia B  pierwsza wersja
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
    mov   eax, r8d               ; RAX = width
    mov   r9d, r9d               ; Zero-extend height to 64 bits
    imul  rax, r9                ; RAX = width * height


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
    test    rax, rax                 ; Check if any pixels remain
    jz      Done                     ; Exit if all pixels are processed

NextByte:
    mov   r10b, 255              ; Set maximum pixel value
    sub   r10b, byte ptr [rcx]   ; Calculate 255 - src[i]
    mov   byte ptr [rdx], r10b   ; Store result in dst[i]

    inc   rcx                    ; Move to next source pixel
    inc   rdx                    ; Move to next destination pixel
    dec   rax                    ; Decrease remaining pixel count
    jnz   NextByte               ; Repeat until all pixels are processed


Done:
    vzeroupper                       ; Clear upper YMM register halves
    ret                              ; Return to the caller
InvertAsm endp




; ------------------------------------------------------------
; SobelAsm - Sobel edge detection (scalar implementation).
; Gx = (tr + 2r + br) - (tl + 2l + bl)
; Gy = (bl + 2b + br) - (tl + 2t + tr)
; G = |Gx| + |Gy|
; dst = 255 if G >= threshold, otherwise 0.
;
; Input:
;   RCX       = src (Gray8 input image)
;   RDX       = dst (separate output buffer)
;   R8D       = width (3..16384)
;   R9D       = height (3..16384)
;   [RSP+40]  = threshold (0..2040)
;
; Output: dst contains 0 or 255, with a black border.
; Modified registers: RAX, RCX, RDX, R8-R11
; Preserved registers: RBX, RSI, RDI, R12-R15
; Modified flags: CF, ZF, SF, OF, PF, AF
; ------------------------------------------------------------

SobelAsm proc
    mov    r10d, dword ptr [rsp+40]   ; Read threshold before pushing registers
    push   rbx
    push   rsi
    push   rdi
    push   r12
    push   r13
    push   r14
    push   r15

    mov    r8d, r8d                   ; Zero-extend width
    mov    r9d, r9d                   ; Zero-extend height
    cmp    r8, 3
    jb     SbExit
    cmp    r9, 3
    jb     SbExit

    ; Clear the entire output buffer
    mov    rax, r8
    imul   rax, r9
    mov    rdi, rdx

SbZeroTail:
    test   rax, rax
    jz     SbZeroDone
    mov    byte ptr [rdi], 0
    inc    rdi
    dec    rax
    jmp    SbZeroTail

SbZeroDone:
    ; Process interior rows
    lea    rsi, [rcx + r8]
    lea    rdi, [rdx + r8]
    mov    r11, r9
    sub    r11, 2

SbRowLoop:
    lea    r12, [rsi + 1]
    lea    r13, [rdi + 1]
    mov    r14, r8
    sub    r14, 2

SbScalarLoop:
    test   r14, r14
    jz     SbNextRow

    mov    rbx, r12
    sub    rbx, r8
    lea    r15, [r12 + r8]

    movzx  edx, byte ptr [rbx+1]     ; tr
    mov    eax, edx
    mov    ecx, edx
    neg    ecx

    movzx  edx, byte ptr [rbx-1]     ; tl
    sub    eax, edx
    sub    ecx, edx

    movzx  edx, byte ptr [r15+1]     ; br
    add    eax, edx
    add    ecx, edx

    movzx  edx, byte ptr [r15-1]     ; bl
    sub    eax, edx
    add    ecx, edx

    movzx  edx, byte ptr [r12+1]     ; r
    lea    eax, [eax + edx*2]

    movzx  edx, byte ptr [r12-1]     ; l
    add    edx, edx
    sub    eax, edx

    movzx  edx, byte ptr [r15]       ; b
    lea    ecx, [ecx + edx*2]

    movzx  edx, byte ptr [rbx]       ; t
    add    edx, edx
    sub    ecx, edx

    ; Calculate absolute gradient values
    mov    edx, eax
    neg    eax
    cmovl  eax, edx

    mov    edx, ecx
    neg    ecx
    cmovl  ecx, edx

    add    eax, ecx

    ; Apply threshold
    xor    edx, edx
    cmp    eax, r10d
    jl     SbStore
    mov    dl, 255

SbStore:
    mov    byte ptr [r13], dl
    inc    r12
    inc    r13
    dec    r14
    jmp    SbScalarLoop

SbNextRow:
    add    rsi, r8
    add    rdi, r8
    dec    r11
    jnz    SbRowLoop

SbExit:
    pop    r15
    pop    r14
    pop    r13
    pop    r12
    pop    rdi
    pop    rsi
    pop    rbx
    ret
SobelAsm endp


end


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



end

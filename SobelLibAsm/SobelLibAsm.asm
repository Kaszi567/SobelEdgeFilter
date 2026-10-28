.code
   ; Testowa procedura: zwraca a + b
   ; Wejście: ECX = a, EDX = b   Wyjście: EAX = a + b
   TestAdd proc
       mov eax, ecx        ; EAX = a
       add eax, edx        ; EAX = a + b
       ret
   TestAdd endp
   end
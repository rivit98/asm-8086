# Assembly projects

## Table of Contents
- [Schema](#schema)
- [Used software](#used-software)
- [Project 1](#project-1)
- [Project 1 solution](#project-1-solution)
- [Project 2](#project-2)
- [Project 2 solution](#project-2-solution)
- [Compiling](#compiling)
- [Pascal](#pascal)

## Schema
![Schema](media/Block-Diagram-of-8086.png)

## Used software
- ml.exe - Microsoft Macro Assembler Version 6.11
- link.exe - linker
- ml.err - list of errors - required by the compiler
- Visual studio code
- DOSBox 0.74-3
- emu8086 (!! it doesn't support vga fonts, see task2)

## Project 1

**Opis:**\
Proszę napisać program szyfrujący plik w oparciu o funkcję XOR i hasło wieloznakowe. Wynikiem działania programu powinna być zaszyfrowana kopia pliku wejściowego.
Zakładając, że zawartością pliku wejściowego jest np. tekst:

"Wszyscy wiedzą, że czegoś nie da się zrobić, aż znajdzie się taki jeden, który nie wie, że się nie da, i on to robi."\
a hasłem jest np.:\
"Albert Einstein "

to wówczas szyfrowanie powinno wyglądać następująco:\
Wszyscy wiedzą, że czegoś nie da się zrobić, aż (…)\
       XOR\
Albert Einstein Albert Einstein Albert Einstein (…)

Zatem hasło powtarzamy tutaj cyklicznie.
Czyli:
'W' xor 'A'\
's' xor 'l'\
'z' xor 'b'\
'y' xor 'e'\
's' xor 'r'\
'c' xor 't'\
'y' xor ' '  (czyli: y xor spacja )\
' ' xor 'E'\
'w' xor 'i'

itd...


Szyfrowanie jest symetryczne, więc tym samym hasłem plik powinien móc być odszyfrowany.\
Przykład wywołania programu:\
```program.exe  plik_wej  plik_wyj  "klucz do szyfrowania tekstu"```

Po uruchomieniu, program powinien wypisać na ekranie wczytane dane, a na końcu powinien wypisać komunikat że proces zakończył się poprawnie lub z błędem.

## Project 1 solution 
[Click to show code](./task1.asm)

## Project 2

**Opis:**\
Proszę napisać program, którego parametrami przy uruchamianiu będą cyfra reprezentująca ZOOM oraz dowolny krótki tekst. Po naciśnięciu klawisza ENTER, program powinien wyświetlić na ekranie w trybie graficznym VGA (320x200, 256 kol) podany wcześniej w linii komend tekst powiększony ZOOM razy, wykorzystując do tego wyłącznie bezpośredni dostęp do pamięci obrazu. Do tworzenia obrazu nie wolno wykorzystywać gotowych funkcji DOS oraz BIOS. Program powinien pozwolić na powrót do systemu operacyjnego po naciśnięciu dowolnego klawisza.

 

Przykład wywołania programu:\
```program.exe 8 "To jest tekst!"```

Efekt może wyglądać np. tak:\
![Przykladowa realizacja](./media/image002.jpg)

## Project 2 solution
I've added ability to scroll text with arrows (left and right)\
[Click to show code](./task2.asm)

## Compiling

Run "ml.exe file.asm" under DOS (I've used DOSBox 0.74-3)

## Pascal
Pascal program was created to figure out how fonts are stored in memory. Code was found on [stackoverflow.com](http://stackoverlow.com). Compile with dos version of turbo pascal 7.x or use PASCAL.EXE :wink:\
[Click to show code](./pascalFontDrawer.pas)

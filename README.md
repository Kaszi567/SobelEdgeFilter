# SobelEdgeFilter
Aplikacja WPF (C#) realizująca filtr Sobela. Projekt porównuje wydajność referencyjnego algorytmu w C# z wysoce zoptymalizowaną biblioteką w asemblerze x86-64 wykorzystującą instrukcje wektorowe SIMD (AVX2/SSE4)

Projekt realizujący wykrywanie krawędzi na obrazach wysokiej rozdzielczości za pomocą maski konwolucyjnej Sobela. Architektura systemu opiera się na ścisłym podziale na warstwę prezentacji i logikę obliczeniową:

Frontend (WPF / C#): Aplikacja okienkowa odpowiadająca za interfejs użytkownika, ładowanie obrazów, walidację danych wejściowych (np. próg odcięcia krawędzi) oraz precyzyjny pomiar czasu wykonania algorytmu z pominięciem czasu renderowania GUI.

Backend C# (Class Library): Referencyjna implementacja algorytmu napisana w języku wysokiego poziomu.

Backend ASM x64 (DLL): Niskopoziomowa, dynamicznie ładowana biblioteka w asemblerze x86-64. Wykorzystuje instrukcje wektorowe SIMD do równoległego przetwarzania danych wielu pikseli w pojedynczym cyklu procesora.

Aplikacja pozwala na dynamiczne przełączanie się między bibliotekami w czasie działania programu, umożliwiając zebranie wiarygodnych danych do analizy zysku wydajnościowego z zastosowania wektoryzacji.

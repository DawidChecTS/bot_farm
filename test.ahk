#Requires AutoHotkey v2
#Include Gdip_All.ahk

CoordMode "Mouse", "Screen"
SetMouseDelay 10 ; Wymusza odstęp czasowy dla akcji myszy

if !A_IsAdmin
{   
    try {
        Run '*RunAs "' A_ScriptFullPath '"'
    }
    ExitApp
}

global FontCache := Map()
LoadFontCache()

global running := false

; --- WŁĄCZNIK / WYŁĄCZNIK PĘTLI GŁÓWNEJ (F1) ---
F1::{
    global running
    running := !running

    if running {
        ToolTip "Bot: WŁĄCZONY"
        SetTimer () => ToolTip(), -1500
        SetTimer(MainLoop, -10)
    } else {
        ToolTip "Bot: WYŁĄCZONY"
        SetTimer () => ToolTip(), -1500
    }
}

; --- PĘTLA GŁÓWNA (CYKL) ---
MainLoop() {
    global running
    
    while (running) {
        ; Sprawdź czy okno pytania jest już widoczne przed rozpoczęciem
        CheckAndSolveCaptcha()

        ; --- KROK 1: Pierwsza sekwencja AoE x5 (BEZ kliknięcia myszą) ---
        Loop 5 {
            if (!running)
                return
            ExecuteAoeSequence(false)
        }

        ; Czekanie 5 sekund
        if !InterruptibleSleep(5000)
            return

        ; --- KROK 2: Czekanie 15 sekund (15000 ms) ---
        if !InterruptibleSleep(10000)
            return

        ; --- KROK 3: Naciśnięcie F12, a następnie W przez 12 sekund ---
        SendInput "{F12 down}"
        Sleep 50
        SendInput "{F12 up}"
        Sleep 100

        SendInput "{w down}"
        wasInterrupted := !InterruptibleSleep(5000) ; Przytrzymanie 6 sekund
        SendInput "{w up}"
        if (wasInterrupted)
            return

        ; --- KROK 4: Druga sekwencja AoE x5 (Z KLIKNIĘCIEM NA ŚRODKU ekranu) ---
        Loop 5 {
            if (!running)
                return
            ExecuteAoeSequence(true) ; true = kliknij na środku
        }

        ; Czekanie 5 sekund
        if !InterruptibleSleep(5000)
            return

        ; --- KROK 5: Naciśnięcie klawisza A ---
        SendInput "{a down}"
        Sleep 50
        SendInput "{a up}"
        
        Sleep 1000
    }
}

InterruptibleSleep(ms) {
    global running
    elapsed := 0
    while (elapsed < ms) {
        if (!running)
            return false
        
        ; Podczas pauzy również kontrolujemy obecność okna zadania
        CheckAndSolveCaptcha()

        Sleep 100
        elapsed += 100
    }
    return true
}

ExecuteAoeSequence(shouldClick := false) {
    global running
    centerX := A_ScreenWidth // 2
    centerY := A_ScreenHeight // 2

    Loop 9 {
        if (!running)
            return

        ; Sprawdzenie obecności captcha PRZED każdym wciśnięciem cyfry!
        CheckAndSolveCaptcha()

        SendInput "{" A_Index " down}"
        Sleep 40
        SendInput "{" A_Index " up}"
        Sleep 40
    }
    
    if (running) {
        ; ZAWSZE pozycjonuj kursor na środku ekranu
        MouseMove centerX, centerY, 0
        Sleep 50

        if (shouldClick) {
            ; Kliknięcie w dokładnie centralnym punkcie ekranu
            SendEvent "{Click Left Down}"
            Sleep 60
            SendEvent "{Click Left Up}"
            Sleep 60

            MouseMove centerX, centerY, 0
            Sleep 50
        }
    }
}

; --- AUTOMATYCZNE WYKRYWANIE I ROZWIAZYWANIE CAPTCHA ---
CheckAndSolveCaptcha() {
    global running
    if (!running)
        return

    centerX := A_ScreenWidth // 2
    centerY := A_ScreenHeight // 2

    ; Pobranie obrazka z obszaru pytania (silent := true blokuje okienka InputBox podczas gry)
    x := 1575, y := 708, w := 120, h := 736 - 708
    expr := ReadPixelEquation(x, y, w, h, true)

    ; Weryfikacja czy odczytano pełny wzór matematyczny (np. 5+6=)
    if (expr != "" && RegExMatch(expr, "^\d+\s*[\+\-\*/]\s*\d+")) {
        ; 1. ZATRZYMAJ wysyłanie cyfr 1-9 na czas wpisywania odpowiedzi
        running := false

        answer := EvalMath(expr)

        if (answer != "") {
            inputX := 1820, inputY := 685  ; Środek czarnego pola tekstowego
            yesX   := 1646, yesY   := 775  ; Środek przycisku YES

            ; 2. Kliknij i aktywuj pole tekstowe
            SendEvent "{Click " inputX ", " inputY "}"
            Sleep 100

            ; 3. Wyczyszczenie pola ze śmieci od prawej do lewej
            SendInput "{End}"
            Sleep 30
            Loop 30 {
                SendInput "{Backspace}"
                Sleep 10
            }
            Sleep 50

            ; 4. Wpisanie wyliczonego wyniku
            SendInput answer
            Sleep 100

            ; 5. Kliknięcie w przycisk YES
            SendEvent "{Click " yesX ", " yesY "}"
            Sleep 200

            ; 6. Wymuszenie powrotu myszy na środek ekranu (pozycja zero)
            SendEvent "{Click " centerX ", " centerY ", 0}"
            Sleep 100
            MouseMove centerX, centerY, 0
            Sleep 200

            ; 7. Wznów pętlę bota
            running := true
            SetTimer(MainLoop, -10)
        } else {
            running := true
            SetTimer(MainLoop, -10)
        }
    }
}

; --- RĘCZNE WYWOŁANIE Z NAUKĄ CZCIONKI (POD F4 / F6) ---
F4::
F6:: {
    x := 1575, y := 708, w := 120, h := 736 - 708
    expr := ReadPixelEquation(x, y, w, h, false) ; silent := false pozwala uczyć skrypt nowych znaków
    if (expr != "") {
        MsgBox "Odczytane równanie: " expr "`nWynik: " EvalMath(expr), "Test OCR"
    } else {
        MsgBox "Nie odczytano równania.", "Test OCR"
    }
}

ReadPixelEquation(x, y, w, h, silent := false) {
    pToken := Gdip_Startup()
    if !pToken
        return ""

    pBitmap := Gdip_BitmapFromScreen(x "|" y "|" w "|" h)
    Gdip_GetImageDimensions(pBitmap, &bw, &bh)

    grid := []
    Loop bh {
        py := A_Index - 1
        row := []
        Loop bw {
            px := A_Index - 1
            argb := Gdip_GetPixel(pBitmap, px, py)
            r := (argb >> 16) & 0xFF
            g := (argb >> 8) & 0xFF
            b := argb & 0xFF

            isText := (r > 110 && g > 110 && (r + g) > (b * 1.8) && (r + g + b) > 240) ? 1 : 0
            row.Push(isText)
        }
        grid.Push(row)
    }

    charBlocks := []
    inChar := false
    startX := 0

    Loop bw {
        col := A_Index - 1
        hasPixel := false
        Loop bh {
            row := A_Index - 1
            if (grid[row+1][col+1] == 1) {
                hasPixel := true
                break
            }
        }

        if (hasPixel && !inChar) {
            inChar := true
            startX := col
        } else if (!hasPixel && inChar) {
            inChar := false
            charBlocks.Push({x1: startX, x2: col - 1})
        }
    }
    if (inChar)
        charBlocks.Push({x1: startX, x2: bw - 1})

    resultStr := ""
    for block in charBlocks {
        charW := block.x2 - block.x1 + 1
        pixelCount := 0
        minY := bh, maxY := 0

        Loop bh {
            py := A_Index - 1
            Loop charW {
                px := block.x1 + A_Index - 1
                if (grid[py+1][px+1] == 1) {
                    pixelCount++
                    if (py < minY)
                        minY := py
                    if (py > maxY)
                        maxY := py
                }
            }
        }

        if (pixelCount <= 0)
            continue

        charH := maxY - minY + 1

        if (charH <= 4 && charW >= 4)
            continue
        if (pixelCount < 5)
            continue

        charHash := GenerateCharHash(grid, block.x1, block.x2, minY, maxY)

        if FontCache.Has(charHash) {
            resultStr .= FontCache[charHash]
        } else {
            ; Jeśli silent = true (praca automatyczna), pomiń nauki
            if (!silent) {
                preview := RenderPreview(grid, block.x1, block.x2, minY, maxY)
                ib := InputBox("Wykryto nowy znak!`nSzerokość=" charW ", Wysokość=" charH "`n`n" preview "`nPodaj symbol (np. 0-9, +, -, *, /):", "Nauka czcionki", "w320 h260")
                
                if (ib.Result == "OK" && ib.Value != "") {
                    charVal := Trim(ib.Value)
                    FontCache[charHash] := charVal
                    IniWrite(charVal, A_ScriptDir "\font_cache.ini", "Hashes", charHash)
                    resultStr .= charVal
                }
            }
        }
    }

    Gdip_DisposeImage(pBitmap)
    Gdip_Shutdown(pToken)

    return resultStr
}

GenerateCharHash(grid, x1, x2, y1, y2) {
    hash := (x2 - x1 + 1) "x" (y2 - y1 + 1) "_"
    Loop (y2 - y1 + 1) {
        py := y1 + A_Index - 1
        Loop (x2 - x1 + 1) {
            px := x1 + A_Index - 1
            hash .= grid[py+1][px+1]
        }
    }
    return hash
}

RenderPreview(grid, x1, x2, y1, y2) {
    str := ""
    Loop (y2 - y1 + 1) {
        py := y1 + A_Index - 1
        Loop (x2 - x1 + 1) {
            px := x1 + A_Index - 1
            str .= (grid[py+1][px+1] == 1) ? "█" : "░"
        }
        str .= "`n"
    }
    return str
}

LoadFontCache() {
    global FontCache
    iniFile := A_ScriptDir "\font_cache.ini"
    if !FileExist(iniFile)
        return

    try {
        sec := IniRead(iniFile, "Hashes")
        Loop Parse, sec, "`n", "`r" {
            if (A_LoopField == "")
                continue
            kv := StrSplit(A_LoopField, "=")
            if (kv.Length == 2)
                FontCache[kv[1]] := kv[2]
        }
    }
}

EvalMath(expr) {
    if !RegExMatch(expr, "^\s*(-?\d+(?:\.\d+)?)\s*([\+\-\*/])\s*(-?\d+(?:\.\d+)?)\s*$", &m)
        return ""
    
    n1 := Float(m[1])
    op := m[2]
    n2 := Float(m[3])

    switch op {
        case "+": res := n1 + n2
        case "-": res := n1 - n2
        case "*": res := n1 * n2
        case "/": res := (n2 != 0) ? (n1 / n2) : ""
    }

    return (res = Floor(res)) ? Integer(res) : res
}

Escape::{
    global running
    running := false
    SendInput "{w up}{a up}"
    ToolTip "Bot: ZATRZYMANE (ESC)"
    SetTimer () => ToolTip(), -1500
}
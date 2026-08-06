#Requires AutoHotkey v2
#Include Gdip_All.ahk

; Wymuszenie dokładnego odczytu pikseli bez przeliczania skalowania Windows (DPI)
DllCall("SetThreadDpiAwarenessContext", "ptr", -3)

CoordMode "Mouse", "Screen"
CoordMode "Pixel", "Screen"
SetMouseDelay 10

if !A_IsAdmin
{   
    try {
        Run '*RunAs "' A_ScriptFullPath '"'
    }
    ExitApp
}

; Inicjalizacja GDI+
global pToken := Gdip_Startup()
OnExit((*) => Gdip_Shutdown(pToken))

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
        ; Sprawdź czy nastąpiło rozłączenie lub wyzwanie Captcha
        if CheckDisconnect()
            return
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

        ; --- KROK 2: Czekanie 10 sekund ---
        if !InterruptibleSleep(10000)
            return

        ; --- KROK 3: Naciśnięcie F12, a następnie W przez 5 sekund ---
        SendInput "{F12 down}"
        Sleep 50
        SendInput "{F12 up}"
        Sleep 100

        SendInput "{w down}"
        wasInterrupted := !InterruptibleSleep(5000)
        SendInput "{w up}"
        if (wasInterrupted)
            return

        ; --- KROK 4: Druga sekwencja AoE x5 (Z KLIKNIĘCIEM NA ŚRODKU ekranu) ---
        Loop 5 {
            if (!running)
                return
            ExecuteAoeSequence(true)
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
        
        if CheckDisconnect()
            return false

        CheckAndSolveCaptcha()

        Sleep 100
        elapsed += 100
    }
    return true
}

; --- FUNKCJA WYKRYWAJĄCA BRAK POŁĄCZENIA / OKNO EKRANU LOGOWANIA ---
CheckDisconnect() {
    global running
    if (!running)
        return false

    ; 1. Sprawdzamy czzerwony przycisk 'Quit' w lewym dolnym rogu (rozdzielczość 1920x1080)
    ; Współrzędne dla lewego dolnego rogu przycisku Quit: X=72, Y=938
    try {
        colorQuit := PixelGetColor(72, 938)
        
        ; Sprawdzamy czy kolor to odcień czerwonego (przycisk Quit widoczny tylko w menu logowania)
        r := (colorQuit >> 16) & 0xFF
        g := (colorQuit >> 8) & 0xFF
        b := colorQuit & 0xFF

        ; Jeśli piksel jest wyraźnie czerwony (R > 100 i R jest dużo większe niż G i B)
        if (r > 120 && g < 40 && b < 40) {
            StopBotDueToDisconnect("Wykryto powrót do ekranu logowania (Przycisk Quit)")
            return true
        }
    }

    ; 2. Zabezpieczenie drugie: Sprawdzamy złoty ramki przycisku OK w oknie "Connection Lost"
    ; Środek ekranu (okienko błędu znajduje się dokładnie na środku)
    try {
        colorOK := PixelGetColor(960, 560) ; Środek przycisku OK
        
        ; Kolor złotawy/złoto-brązowy okna komunikatu
        rOK := (colorOK >> 16) & 0xFF
        gOK := (colorOK >> 8) & 0xFF
        bOK := colorOK & 0xFF

        if (rOK > 100 && gOK > 60 && bOK < 40) {
            StopBotDueToDisconnect("Wykryto okno błędu połączenia (Connection Lost)")
            return true
        }
    }

    return false
}

StopBotDueToDisconnect(reason) {
    global running
    running := false
    SendInput "{w up}{a up}{F12 up}"
    
    ; Sygnał dźwiękowy (3 krótkie piski ostrzegawcze)
    Loop 3 {
        SoundBeep 750, 150
        Sleep 50
    }

    ToolTip "BOT ZATRZYMANY: " reason
    SetTimer () => ToolTip(), -5000
}

ExecuteAoeSequence(shouldClick := false) {
    global running
    centerX := A_ScreenWidth // 2
    centerY := A_ScreenHeight // 2

    Loop 9 {
        if (!running)
            return

        if CheckDisconnect()
            return

        CheckAndSolveCaptcha()

        SendInput "{" A_Index " down}"
        Sleep 40
        SendInput "{" A_Index " up}"
        Sleep 40
    }
    
    if (running) {
        MouseMove centerX, centerY, 0
        Sleep 50

        if (shouldClick) {
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

    x := 615, y := 775, w := 120, h := 35
    expr := ReadPixelEquation(x, y, w, h, true)

    if (expr != "" && RegExMatch(expr, "\d+\s*[\+\-\*/]\s*\d+")) {
        running := false

        answer := EvalMath(expr)

        if (answer != "") {
            inputX := 780, inputY := 780   ; Środek czarnego pola tekstowego
            yesX   := 665, yesY   := 850   ; Środek przycisku YES

            SendEvent "{Click " inputX ", " inputY "}"
            Sleep 100

            SendInput "{End}"
            Sleep 30
            Loop 30 {
                SendInput "{Backspace}"
                Sleep 10
            }
            Sleep 50

            SendInput answer
            Sleep 100

            SendEvent "{Click " yesX ", " yesY "}"
            Sleep 200

            SendEvent "{Click " centerX ", " centerY ", 0}"
            Sleep 100
            MouseMove centerX, centerY, 0
            Sleep 200

            running := true
            SetTimer(MainLoop, -10)
        } else {
            running := true
            SetTimer(MainLoop, -10)
        }
    }
}

; --- RĘCZNE WYWOŁANIE Z NAUKĄ CZCIONKI (F4 / F6) ---
F4::
F6:: {
    x := 615, y := 775, w := 120, h := 35
    expr := ReadPixelEquation(x, y, w, h, false)
    if (expr != "") {
        MsgBox "Odczytane równanie: " expr "`nWynik: " EvalMath(expr), "Test OCR"
    } else {
        MsgBox "Nie odczytano równania.", "Test OCR"
    }
}

ReadPixelEquation(x, y, w, h, silent := false) {
    pBitmap := Gdip_BitmapFromScreen(x "|" y "|" w "|" h)
    if !pBitmap
        return ""

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
    if !RegExMatch(expr, "^\s*(-?\d+(?:\.\d+)?)\s*([\+\-\*/])\s*(-?\d+(?:\.\d+)?)\s*=?", &m)
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
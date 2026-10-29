tell application "Ghostty"
    set out to {}
    repeat with w in windows
        set tabsInfo to {}
        repeat with t in tabs of w
            set cwds to working directory of every terminal of t
            set end of tabsInfo to {name of t, cwds}
        end repeat
        set end of out to {id of w, tabsInfo}
    end repeat
    return out
end tell

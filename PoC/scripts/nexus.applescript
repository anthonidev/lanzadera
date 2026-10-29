tell application "Ghostty"
    set cfg to new surface configuration
    set initial working directory of cfg to "/Users/tonis/nexus/nexus-backend"
    set w to new window with configuration cfg
    set t1 to selected tab of w
    set name override of t1 to "🔴 BACKEND"
    set p1 to focused terminal of t1
    set p2 to split p1 direction right with configuration cfg
    set p3 to split p2 direction right with configuration cfg
    set eq to perform action "equalize_splits" on p1
    set cfg2 to new surface configuration
    set initial working directory of cfg2 to "/Users/tonis/nexus/nexus-frontend"
    set t2 to new tab in w with configuration cfg2
    set name override of t2 to "🔴 FRONTEND"
    set q1 to focused terminal of t2
    split q1 direction right with configuration cfg2
    set cfg3 to new surface configuration
    set initial working directory of cfg3 to "/Users/tonis/nexus"
    set t3 to new tab in w with configuration cfg3
    set name override of t3 to "🔴 GLOBAL"
    select tab t1
    focus p2
    return {id of w, id of t1, id of t2, id of t3, class of p2, eq}
end tell

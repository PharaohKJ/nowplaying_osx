tell application "iTunes"
    set pl to (get (first playlist whose name is "__PLAYLIST__"))
    set view of front browser window to pl
    stop
    tell pl
        set shuffle to not shuffle
        set shuffle to not shuffle
    end tell
end tell

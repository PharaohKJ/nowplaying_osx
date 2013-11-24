tell application "iTunes"
    set pl to (get (first playlist whose name is "__PLAYLIST__"))
    set view of front browser window to pl
    stop
    next track
    play
end tell

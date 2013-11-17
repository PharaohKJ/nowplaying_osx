tell application "iTunes"
    set i_name to the name of current track
    set i_artist to artist of current track
    set i_album to album of current track
    set i_rating to rating of current track
    i_name&"/***/"&i_artist&"/***/"&i_album&"/***/"&i_rating
end tell

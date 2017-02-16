#!/bin/bash

######################################################
# Begin Character LCD Display - eventcmd
# by V. Loschiavo - 12FEB2017
# Based on: https://github.com/AyMac/Pandoras-Box
######################################################


# User Defined variables
OUTFILE=/var/tmp/pandoraout
PARSEANDWRITE2LCD=~/.config/pianobar/ParseAndWrite.py

# Put data from piano bar into variables
while read L; do
        k="`echo "$L" | cut -d '=' -f 1`"
        v="`echo "$L" | cut -d '=' -f 2`"
        export "$k=$v"
done < <(grep -e '^\(title\|artist\|album\|stationName\|songStationName\|pRet\|pRetStr\|wRet\|wRetStr\|songDuration\|songPlayed\|rating\|coverArt\|stationCount\|station[0-9]*\)=' /dev/stdin) # don't overwrite $1...

case "$1" in
        songstart)

                # Put title, artist, and station name into a file so we can display on the LCD
                echo -e "$title\n$artist\n$stationName" > $OUTFILE
                $PARSEANDWRITE2LCD
esac

######################################################
#  Patiobar eventcmd script below this point
#  see: https://github.com/kylejohnson/Patiobar
######################################################

# User defined variables #

host="http://127.0.0.1"
port=3000
baseurl="${host}:${port}"


# Here be dragons! #
# (Don't change anything below) #
######################################################
#stationList="${HOME}/.config/pianobar/stationList"
#currentSong="${HOME}/.config/pianobar/currentSong"

stationList="/var/tmp/stationList"
currentSong="/var/tmp/currentSong"

while read L; do
	k="`echo "$L" | cut -d '=' -f 1`"
	v="`echo "$L" | cut -d '=' -f 2`"
	export "$k=$v"
done < <(grep -e '^\(title\|artist\|album\|stationName\|songStationName\|pRet\|pRetStr\|wRet\|wRetStr\|songDuration\|songPlayed\|rating\|coverArt\|stationCount\|station[0-9]*\)=' /dev/stdin) # don't overwrite $1...

post () {
	url=${baseurl}${1}
	curl -s -XPOST $url >/dev/null 2>&1
}

clean () {
	query=$1
	clean=$(echo $query | sed 's/ /%20/g')
	post $clean
}

stationList () {
	if [ -f "$stationList" ]; then
		rm "$stationList"
	fi

	end=`expr $stationCount - 1`
	
	for i in $(eval echo "{0..$end}"); do
		sn=station${i}
		eval sn=\$$sn
		echo "${i}:${sn}" >> "$stationList"
	done
}

case "$1" in
	songstart)
		query="/start/?title=${title}&artist=${artist}&coverArt=${coverArt}&album=${album}&rating=${rating}"
		clean "$query"

		echo -n "${artist},${title},${album},${coverArt},${rating}" > "$currentSong"

		stationList
		;;

#	songfinish)
#		;;

	songlove)
		query="/lovehate/?rating=${rating}"
		clean $query
		;;

#	songshelf)
#		;;

	songban)
		query="/lovehate/?rating=${rating}"
		clean $query
		;;

#	songbookmark)
#		;;

#	artistbookmark)
#		;;

esac

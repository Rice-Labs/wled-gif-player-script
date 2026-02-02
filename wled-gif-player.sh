#!/bin/bash
source /wled-video/.env/bin/activate

WLED_HOST="192.168.0.43"
MEDIA_DIR="/wled-video/media"
PYTHON="/wled-video/.env/bin/python"

LOOPS_PER_VIDEO=4
STREAM_PID=0

start_stream() {
    (
        trap "exit" TERM INT

        while true; do
            ls -1 "$MEDIA_DIR" | shuf | while read -r FILE; do
                FULLPATH="$MEDIA_DIR/$FILE"
                [ -f "$FULLPATH" ] || continue

                for ((i=1; i<=LOOPS_PER_VIDEO; i++)); do
                    echo "Playing $FULLPATH (loop $i/$LOOPS_PER_VIDEO)"

                    "$PYTHON" /wled-video/WLED-video/wledvideo.py \
                        --host "$WLED_HOST" \
                        "$FULLPATH" \
                        --width 32 \
                        --height 32
                done
            done
        done
    ) &

    STREAM_PID=$!
}

stop_stream() {
    if [ "$STREAM_PID" -ne 0 ]; then
        echo "Stopping stream..."
        # Kill entire process group (subshell + python children)
        kill -TERM -"$STREAM_PID" 2>/dev/null
        wait "$STREAM_PID" 2>/dev/null
        STREAM_PID=0
    fi
}

while true; do
    if curl -s --max-time 2 "http://$WLED_HOST/json/state" | jq -r '.on' | grep -q true; then
        if [ "$STREAM_PID" -eq 0 ] || ! kill -0 "$STREAM_PID" 2>/dev/null; then
            echo "$(date) - WLED is ON → starting playback"
            start_stream
        fi
    else
        stop_stream
    fi
done

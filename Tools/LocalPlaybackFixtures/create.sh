#!/bin/bash
# Synthetic playback fixtures; no copyrighted media. MPL-2.0.
set -euo pipefail
out="${1:-build/local-fixtures}"
mkdir -p "$out"
command -v ffmpeg >/dev/null || { echo 'ffmpeg is required.' >&2; exit 1; }
cat > "$out/captions.srt" <<'SRT'
1
00:00:01,000 --> 00:00:10,000
kurtz local playback: subtitle track one

2
00:00:11,000 --> 00:00:59,000
External subtitles are working.
SRT
cat > "$out/external.ass" <<'ASS'
[Script Info]
ScriptType: v4.00+
PlayResX: 1280
PlayResY: 720
[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: Default,Helvetica,38,&H0000FFFF,&H000000FF,&H00000000,&H80000000,0,0,0,0,100,100,0,0,1,2,1,2,10,10,30,1
[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
Dialogue: 0,0:00:00.00,0:10:00.00,Default,,0,0,0,,kurtz: styled external ASS subtitles
ASS
if [[ ! -f "$out/multi.mp4" ]]; then
    ffmpeg -hide_banner -loglevel error -n -f lavfi -i 'testsrc2=size=1280x720:rate=30' \
        -f lavfi -i 'sine=frequency=440:sample_rate=48000' \
        -f lavfi -i 'sine=frequency=880:sample_rate=48000' -i "$out/captions.srt" \
        -t 60 -map 0:v -map 1:a -map 2:a -map 3:s \
        -c:v libx264 -preset ultrafast -crf 20 -pix_fmt yuv420p -c:a aac -c:s mov_text \
        -metadata:s:a:0 language=eng -metadata:s:a:1 language=deu -metadata:s:s:0 language=eng "$out/multi.mp4"
fi
for extension in mov mkv; do
    if [[ ! -f "$out/sample.$extension" ]]; then
        subtitle_codec=copy
        [[ "$extension" == mkv ]] && subtitle_codec=srt
        ffmpeg -hide_banner -loglevel error -n -i "$out/multi.mp4" -map 0 -c copy -c:s "$subtitle_codec" "$out/sample.$extension"
    fi
done
if [[ ! -f "$out/long.mp4" ]]; then
    ffmpeg -hide_banner -loglevel error -n -stream_loop 4 -i "$out/multi.mp4" -map 0 -c copy "$out/long.mp4"
fi
printf 'This is deliberately not a media stream.\n' > "$out/corrupt.mkv"
if [[ "${2:-}" == --high-bitrate && ! -f "$out/hevc-4k.mov" ]]; then
    ffmpeg -hide_banner -loglevel error -n -f lavfi -i 'testsrc2=size=3840x2160:rate=30' \
        -f lavfi -i 'sine=frequency=440:sample_rate=48000' -t 20 \
        -c:v hevc_videotoolbox -b:v 45M -tag:v hvc1 -c:a aac -b:a 192k "$out/hevc-4k.mov"
fi
printf 'Fixtures ready in %s\n' "$out"

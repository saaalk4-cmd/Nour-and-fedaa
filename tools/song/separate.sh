#!/usr/bin/env bash
# يفصل صوت الغناء عن المزيكا في أغنية فداء ونور (أكابيلا) بـ Demucs، على أجهزة GitHub (فيها نت).
# الناتج: song_vocals.mp3 يُرفع كملف في release باسم song-vocals، ثم يُنقل يدويًا إلى assets/audio/song/.
# غيّر SONG_VERSION لإعادة التشغيل.
set -euo pipefail
SONG_VERSION=1
pip install --quiet "demucs==4.0.1" "torchaudio<2.6" soundfile
python3 -m demucs --two-stems=vocals -n htdemucs -o out tools/song/original.mp3
v=out/htdemucs/original/vocals.wav
# تنظيف خفيف: إزالة الهمهمة الخفيفة تحت 80Hz وبقايا تحت -50dB، ثم 128k ستيريو
ffmpeg -v error -y -i "$v" -af "highpass=f=80,afftdn=nf=-50,loudnorm=I=-16:TP=-1.5:LRA=11" -codec:a libmp3lame -b:a 128k song_vocals.mp3
ls -l song_vocals.mp3

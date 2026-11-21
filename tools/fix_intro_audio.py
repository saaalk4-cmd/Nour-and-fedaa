#!/usr/bin/env python3
"""يصلح كلمة «الأرنب» في فيلم المقدمة أثناء البناء في CI.

في الفيلم (assets/videos/cinematic_intro.mp4) من 25.5 إلى 28.0 ثانية تقول البنت:
«وكمان الأرنب اللطيف» لكن كلمة «الأرنب» تُنطق ناقصة («الأرن»). حُدد التوقيت بتفريغ
الكلام آليًا (faster-whisper) ومطابقة المشهد (الأرنب يظهر في نفس اللحظة).

الحل: تُنطق الجملة كاملة بصوت عالي الجودة (edge-tts) وتوضع مكانها، مع خفض صوت الفيلم
الأصلي في تلك الثواني فقط (الموسيقى تبقى خافتة تحتها ثم تعود). الصورة لا تتغير.
لا يفشل البناء أبدًا: لو تعذر أي شيء يبقى الفيلم كما هو.

الاستعمال: python3 tools/fix_intro_audio.py   (يحتاج ffmpeg و pip install edge-tts)
"""
import asyncio
import os
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
VIDEO = os.path.join(ROOT, 'assets', 'videos', 'cinematic_intro.mp4')
PHRASE = 'وكمان الأرنب اللطيف!'
START, END = 25.45, 28.05          # الجملة الأصلية
VOICE = os.environ.get('INTRO_VOICE', 'ar-EG-SalmaNeural')
PITCH = os.environ.get('INTRO_PITCH', '+45Hz')  # أقرب لصوت طفلة


def duration(path):
    out = subprocess.run(['ffprobe', '-v', 'error', '-show_entries', 'format=duration', '-of', 'csv=p=0', path],
                         capture_output=True, text=True, check=True).stdout
    return float(out.strip())


async def tts(path):
    import edge_tts  # noqa: PLC0415
    await edge_tts.Communicate(PHRASE, VOICE, rate='+0%', pitch=PITCH).save(path)


def main():
    if not os.path.exists(VIDEO) or not shutil.which('ffmpeg'):
        print('intro fix skipped: no video or ffmpeg')
        return 0
    tmp = tempfile.mkdtemp()
    try:
        voice = os.path.join(tmp, 'v.mp3')
        asyncio.run(tts(voice))
        span = END - START - 0.2
        d = duration(voice)
        tempo = max(1.0, d / span)  # نسرّع قليلًا فقط لو أطول من مكانها
        out = os.path.join(tmp, 'out.mp4')
        # صوت الفيلم ينخفض إلى 12% بنعومة خلال الجملة فقط، والجملة الجديدة فوقه.
        duck = "volume='1-0.88*clip((t-%.2f)/0.12,0,1)*clip((%.2f-t)/0.12,0,1)':eval=frame" % (START - 0.1, END + 0.1)
        delay = int((START + 0.08) * 1000)
        graph = ('[0:a]%s[a0];[1:a]atempo=%.3f,volume=1.5,adelay=%d|%d[a1];'
                 '[a0][a1]amix=inputs=2:duration=first:normalize=0[a]') % (duck, tempo, delay, delay)
        subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', VIDEO, '-i', voice, '-filter_complex', graph,
                        '-map', '0:v', '-c:v', 'copy', '-map', '[a]', '-c:a', 'aac', '-b:a', '128k',
                        '-movflags', '+faststart', out], check=True)
        assert abs(duration(out) - duration(VIDEO)) < 0.3
        shutil.move(out, VIDEO)
        print('intro fixed: "%s" at %.2f-%.2fs (voice %s, tempo %.2f)' % (PHRASE, START, END, VOICE, tempo))
    except Exception as e:  # noqa: BLE001
        print('intro fix skipped:', e)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    return 0


if __name__ == '__main__':
    sys.exit(main())

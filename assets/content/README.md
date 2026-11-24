# محتوى التطبيق

ملفات JSON للدروس تُضاف هنا في المراحل القادمة (قرآن، أذكار، سيرة...).
كل عنصر ديني يجب أن يحمل `source_type` والمصدر. راجع docs/ARCHITECTURE.md.

## الدروس (`lessons/*.json`)

```json
{
  "id": "معرّف فريد",
  "title": "عنوان الدرس",
  "subtitle": "اختياري (مثل اسم السورة)",
  "band": "buraem | atfal | nashia | murahiqun",
  "source_type": "quran | sahih_sunnah | seerah | scholars | educational",
  "source_note": "المصدر أو ملاحظة عنه",
  "content_verified": false,
  "steps": [{"type": "listen"}, {"type": "repeat", "times": 3}, {"type": "reward", "stars": 3}]
}
```

- `content_verified` يبقى `false` حتى يراجع المراجع الشرعي المحتوى.
- نص القرآن لا يُكتب يدويًا: يُستورد من مصدر مرخّص مع فحص عدد الآيات.

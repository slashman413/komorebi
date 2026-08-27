import csv

input_file = "src/locale/locale_table.csv"
output_file = "src/locale/locale_table.csv"

# Current rows, we will parse them and add a 'ja' column
rows = []
with open(input_file, "r", encoding="utf-8") as f:
    reader = csv.reader(f)
    header = next(reader)
    if "ja" not in header:
        header.append("ja")
    rows.append(header)
    for row in reader:
        # If ja is missing, pad it with empty string or simple translation
        while len(row) < len(header):
            row.append("")
        rows.append(row)

# Ja translations for existing strings (best effort / placeholders if needed)
ja_dict = {
    "ui_start": "スタート",
    "ui_options": "オプション",
    "ui_quit": "終了",
    "level_intro": "吸って。吐いて。",
    "ui_wishlist": "Steamでウィッシュリストに追加",
    "ui_demo": "itch.ioでデモをプレイ",
    "spike_title": "木漏れ日 · 呼吸スパイク",
    "phase_inhale": "吸う",
    "phase_hold": "止める",
    "phase_exhale": "吐く",
    "drift_header": "木漏れ日 · 呼吸スパイク (F3で非表示)",
    "drift_fps": "FPS",
    "drift_fps_target": "  (目標 60)",
    "drift_phase": "フェーズ",
    "drift_amplitude": "振幅",
    "drift_clock_frame": "クロック (フレーム)",
    "drift_clock_wall": "クロック (ウォール)",
    "drift_drift": "ドリフト",
    "drift_drift_peak": "(ピーク",
    "drift_haptics": "ハプティクス",
    "drift_haptics_available": "利用可能",
    "drift_haptics_unavailable": "利用不可",
}

for i in range(1, len(rows)):
    key = rows[i][0]
    if key in ja_dict:
        rows[i][3] = ja_dict[key]

# Add new entries for ending
new_entries = [
    ["ending_text", "The peak is reached. Breathe.", "已达巅峰。呼吸。", "山頂に到達しました。深呼吸して。"],
    ["ending_subtext", "Thank you for playing the demo.", "感谢游玩演示版。", "デモをプレイしていただきありがとうございます。"]
]

for entry in new_entries:
    rows.append(entry)

with open(output_file, "w", encoding="utf-8", newline='') as f:
    writer = csv.writer(f)
    writer.writerows(rows)

print("Locales updated.")

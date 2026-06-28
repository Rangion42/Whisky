#!/usr/bin/env python3
"""Insert GPTK localization strings into Localizable.xcstrings at the correct alphabetical position."""

# Read the original file
xcstrings_path = '/Users/bdunwoodie/Documents/GitHub/Whisky/Whisky/Localizable.xcstrings'
with open(xcstrings_path, 'r') as f:
    content = f.read()

# GPTK localization strings to insert (formatted exactly like existing entries)
gptk_strings = '''    "config.gptk.found" : {
      "localizations" : {
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "GPTK detected"
          }
        },
        "zh-Hans" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "检测到 GPTK"
          }
        },
        "zh-Hant" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "偵測到 GPTK"
          }
        },
        "ja" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "GPTKを検出しました"
          }
        },
        "ko" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "GPTK 감지됨"
          }
        },
        "de" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "GPTK erkannt"
          }
        },
        "fr" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "GPTK détecté"
          }
        },
        "es" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "GPTK detectado"
          }
        },
        "it" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "GPTK rilevato"
          }
        },
        "pt-BR" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "GPTK detectado"
          }
        },
        "pt-PT" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "GPTK detetado"
          }
        },
        "ru" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "GPTK обнаружен"
          }
        },
        "ar" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "تم اكتشاف GPTK"
          }
        },
        "cs" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "GPTK zjištěn"
          }
        },
        "da" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "GPTK registreret"
          }
        },
        "fi" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "GPTK havaittu"
          }
        },
        "nl" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "GPTK gedetecteerd"
          }
        },
        "pl" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Wykryto GPTK"
          }
        },
        "ro" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "GPTK detectat"
          }
        },
        "tr" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "GPTK algılandı"
          }
        },
        "uk" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "GPTK виявлено"
          }
        },
        "vi" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Đã phát hiện GPTK"
          }
        }
      }
    },
    "config.gptk.notFound" : {
      "localizations" : {
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "GPTK not found"
          }
        },
        "zh-Hans" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "未检测到 GPTK"
          }
        },
        "zh-Hant" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "未偵測到 GPTK"
          }
        },
        "ja" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "GPTKが見つかりません"
          }
        },
        "ko" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "GPTK를 찾을 수 없음"
          }
        },
        "de" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "GPTK nicht gefunden"
          }
        },
        "fr" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "GPTK introuvable"
          }
        },
        "es" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "GPTK no encontrado"
          }
        },
        "it" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "GPTK non trovato"
          }
        },
        "pt-BR" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "GPTK não encontrado"
          }
        },
        "pt-PT" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "GPTK não encontrado"
          }
        },
        "ru" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "GPTK не найден"
          }
        },
        "ar" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "لم يتم العثور على GPTK"
          }
        },
        "cs" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "GPTK nebyl nalezen"
          }
        },
        "da" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "GPTK ikke fundet"
          }
        },
        "fi" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "GPTK ei löydy"
          }
        },
        "nl" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "GPTK niet gevonden"
          }
        },
        "pl" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Nie znaleziono GPTK"
          }
        },
        "ro" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "GPTK nu a fost găsit"
          }
        },
        "tr" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "GPTK bulunamadı"
          }
        },
        "uk" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "GPTK не знайдено"
          }
        },
        "vi" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Không tìm thấy GPTK"
          }
        }
      }
    },'''

# Find the insertion point - right before "config.enhacnedSync.esync"
insertion_marker = '    "config.enhacnedSync.esync"'
if insertion_marker in content:
    # Insert the GPTK strings before this marker
    new_content = content.replace(insertion_marker, gptk_strings + '\n' + insertion_marker)
    
    # Write the modified content back to the file
    with open(xcstrings_path, 'w') as f:
        f.write(new_content)
    
    print("GPTK localization strings inserted successfully!")
else:
    print(f"Could not find insertion marker: {insertion_marker}")

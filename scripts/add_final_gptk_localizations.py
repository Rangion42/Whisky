#!/usr/bin/env python3
"""Add remaining GPTK localization strings to Localizable.xcstrings."""

import re

xcstrings_path = '/Users/bdunwoodie/Documents/GitHub/Whisky/Whisky/Localizable.xcstrings'
with open(xcstrings_path, 'r') as f:
    content = f.read()

# Helper to create a localization entry block for one key with all languages
def make_entry(key, en_value):
    """Create a full localization entry block for one key."""
    
    # Provide reasonable translations for common strings
    trans = {
        "config.gptk.compat.notes.count": {"zh-Hans": "%d 条兼容性说明", "zh-Hant": "%d 條兼容性說明",
                                           "ja": "%d 件の互換性ノート", "ko": "%d 개의 호환성 메모",
                                           "de": "%d Kompatibilitätsnotizen", "fr": "%d notes de compatibilité",
                                           "es": "%d notas de compatibilidad", "it": "%d note di compatibilità",
                                           "pt-BR": "%d notas de compatibilidade", "pt-PT": "%d notas de compatibilidade",
                                           "ru": "%d заметок о совместимости", "ar": "%d ملاحظات التوافق",
                                           "cs": "%d poznámek o kompatibilitě", "da": "%d kompatibilitetsnoter",
                                           "fi": "%d yhteensopivuusmuistiinpanoa", "nl": "%d compatibiliteitsnotities",
                                           "pl": "%d notatek kompatybilności", "ro": "%d note de compatibilitate",
                                           "tr": "%d uyumluluk notu", "uk": "%d нотаток про сумісність",
                                           "vi": "%d ghi chú tương thích"},
        "config.gptk.memory.auto": {"zh-Hans": "自动", "zh-Hant": "自動",
                                    "ja": "自動", "ko": "자동",
                                    "de": "Auto", "fr": "Auto",
                                    "es": "Auto", "it": "Auto",
                                    "pt-BR": "Auto", "pt-PT": "Auto",
                                    "ru": "Авто", "ar": "تلقائي",
                                    "cs": "Auto", "da": "Auto",
                                    "fi": "Automaattinen", "nl": "Auto",
                                    "pl": "Auto", "ro": "Auto",
                                    "tr": "Otomatik", "uk": "Авто",
                                    "vi": "Tự động"},
        "config.gptk.memory.limited": {"zh-Hans": "限制", "zh-Hant": "限制",
                                       "ja": "制限", "ko": "제한",
                                       "de": "Begrenzt", "fr": "Limité",
                                       "es": "Limitado", "it": "Limitato",
                                       "pt-BR": "Limitado", "pt-PT": "Limitado",
                                       "ru": "Ограниченный", "ar": "محدود",
                                       "cs": "Omezený", "da": "Begrænset",
                                       "fi": "Rajoitettu", "nl": "Beperkt",
                                       "pl": "Ograniczony", "ro": "Limitat",
                                       "tr": "Sınırlı", "uk": "Обмежений",
                                       "vi": "Giới hạn"},
        "config.gptk.metrics.cpu": {"zh-Hans": "CPU", "zh-Hant": "CPU",
                                    "ja": "CPU", "ko": "CPU",
                                    "de": "CPU", "fr": "CPU",
                                    "es": "CPU", "it": "CPU",
                                    "pt-BR": "CPU", "pt-PT": "CPU",
                                    "ru": "ЦП", "ar": "وحدة المعالجة المركزية",
                                    "cs": "CPU", "da": "CPU",
                                    "fi": "CPU", "nl": "CPU",
                                    "pl": "CPU", "ro": "CPU",
                                    "tr": "İşlemci", "uk": "ЦП",
                                    "vi": "CPU"},
        "config.gptk.metrics.gpu": {"zh-Hans": "GPU", "zh-Hant": "GPU",
                                    "ja": "GPU", "ko": "GPU",
                                    "de": "GPU", "fr": "GPU",
                                    "es": "GPU", "it": "GPU",
                                    "pt-BR": "GPU", "pt-PT": "GPU",
                                    "ru": "ГП", "ar": "وحدة معالجة الرسومات",
                                    "cs": "GPU", "da": "GPU",
                                    "fi": "GPU", "nl": "GPU",
                                    "pl": "GPU", "ro": "GPU",
                                    "tr": "Ekran Kartı", "uk": "ГП",
                                    "vi": "GPU"},
        "config.gptk.metrics.memory": {"zh-Hans": "内存", "zh-Hant": "記憶體",
                                       "ja": "メモリ", "ko": "메모리",
                                       "de": "Speicher", "fr": "Mémoire",
                                       "es": "Memoria", "it": "Memoria",
                                       "pt-BR": "Memória", "pt-PT": "Memória",
                                       "ru": "Память", "ar": "الذاكرة",
                                       "cs": "Paměť", "da": "Hukommelse",
                                       "fi": "Muisti", "nl": "Geheugen",
                                       "pl": "Pamięć", "ro": "Memorie",
                                       "tr": "Bellek", "uk": "Пам'ять",
                                       "vi": "Bộ nhớ"},
        "config.gptk.metrics.refresh": {"zh-Hans": "刷新", "zh-Hant": "重新整理",
                                        "ja": "更新", "ko": "새로 고침",
                                        "de": "Aktualisieren", "fr": "Actualiser",
                                        "es": "Actualizar", "it": "Aggiorna",
                                        "pt-BR": "Atualizar", "pt-PT": "Atualizar",
                                        "ru": "Обновить", "ar": "تحديث",
                                        "cs": "Obnovit", "da": "Opdater",
                                        "fi": "Päivitä", "nl": "Vernieuwen",
                                        "pl": "Odśwież", "ro": "Reîmprospătare",
                                        "tr": "Yenile", "uk": "Оновити",
                                        "vi": "Làm mới"},
        "config.gptk.perf.balanced": {"zh-Hans": "平衡", "zh-Hant": "平衡",
                                      "ja": "バランス", "ko": "균형",
                                      "de": "Ausgewogen", "fr": "Équilibré",
                                      "es": "Equilibrado", "it": "Bilanciato",
                                      "pt-BR": "Equilibrado", "pt-PT": "Equilibrado",
                                      "ru": "Сбалансированный", "ar": "متوازن",
                                      "cs": "Vyvážený", "da": "Balanceret",
                                      "fi": "Tasapainoinen", "nl": "Gebalanceerd",
                                      "pl": "Zbalansowany", "ro": "Echilibrat",
                                      "tr": "Dengeli", "uk": "Збалансований",
                                      "vi": "Cân bằng"},
        "config.gptk.perf.performance": {"zh-Hans": "性能", "zh-Hant": "效能",
                                         "ja": "パフォーマンス", "ko": "성능",
                                         "de": "Leistung", "fr": "Performance",
                                         "es": "Rendimiento", "it": "Prestazioni",
                                         "pt-BR": "Desempenho", "pt-PT": "Desempenho",
                                         "ru": "Производительность", "ar": "الأداء",
                                         "cs": "Výkon", "da": "Ydelse",
                                         "fi": "Suorituskyky", "nl": "Prestatie",
                                         "pl": "Wydajność", "ro": "Performanță",
                                         "tr": "Performans", "uk": "Продуктивність",
                                         "vi": "Hiệu suất"},
        "config.gptk.perf.quality": {"zh-Hans": "质量", "zh-Hant": "品質",
                                     "ja": "品質", "ko": "품질",
                                     "de": "Qualität", "fr": "Qualité",
                                     "es": "Calidad", "it": "Qualità",
                                     "pt-BR": "Qualidade", "pt-PT": "Qualidade",
                                     "ru": "Качество", "ar": "الجودة",
                                     "cs": "Kvalita", "da": "Kvalitet",
                                     "fi": "Laatu", "nl": "Kwaliteit",
                                     "pl": "Jakość", "ro": "Calitate",
                                     "tr": "Kalite", "uk": "Якість",
                                     "vi": "Chất lượng"},
        "config.gptk.presets.count": {"zh-Hans": "%d 个预设", "zh-Hant": "%d 個預設",
                                      "ja": "%d 件のプリセット", "ko": "%d 개의 사전 설정",
                                      "de": "%d Voreinstellungen", "fr": "%d préréglages",
                                      "es": "%d ajustes preestablecidos", "it": "%d preset",
                                      "pt-BR": "%d predefinições", "pt-PT": "%d predefinições",
                                      "ru": "%d пресетов", "ar": "%d إعدادات مسبقة",
                                      "cs": "%d přednastavení", "da": "%d forudindstillinger",
                                      "fi": "%d esiasetusta", "nl": "%d voorinstellingen",
                                      "pl": "%d presetów", "ro": "%d presetări",
                                      "tr": "%d ön ayar", "uk": "%d пресетів",
                                      "vi": "%d cài đặt sẵn"},
        "config.gptk.shader.compileOnLaunch": {"zh-Hans": "启动时编译",
                                               "zh-Hant": "啟動時編譯",
                                               "ja": "起動時にコンパイル",
                                               "ko": "실행 시 컴파일",
                                               "de": "Beim Start kompilieren",
                                               "fr": "Compiler au lancement",
                                               "es": "Compilar al iniciar",
                                               "it": "Compila all'avvio",
                                               "pt-BR": "Compilar ao iniciar",
                                               "pt-PT": "Compilar ao iniciar",
                                               "ru": "Компилировать при запуске",
                                               "ar": "ترجمة عند التشغيل",
                                               "cs": "Přeložit při spuštění",
                                               "da": "Kompilér ved start",
                                               "fi": "Käännä käynnistyksen yhteydessä",
                                               "nl": "Compileren bij opstarten",
                                               "pl": "Kompiluj przy uruchomieniu",
                                               "ro": "Compilare la lansare",
                                               "tr": "Başlatma Sırasında Derle",
                                               "uk": "Компілювати при запуску",
                                               "vi": "Biên dịch khi khởi chạy"},
        "config.gptk.shader.disabled": {"zh-Hans": "禁用", "zh-Hant": "停用",
                                        "ja": "無効", "ko": "사용 안 함",
                                        "de": "Deaktiviert", "fr": "Désactivé",
                                        "es": "Desactivado", "it": "Disabilitato",
                                        "pt-BR": "Desativado", "pt-PT": "Desativado",
                                        "ru": "Отключено", "ar": "معطل",
                                        "cs": "Zakázáno", "da": "Deaktiveret",
                                        "fi": "Poistettu käytöstä", "nl": "Uitgeschakeld",
                                        "pl": "Wyłączony", "ro": "Dezactivat",
                                        "tr": "Devre Dışı", "uk": "Вимкнено",
                                        "vi": "Đã tắt"},
        "config.gptk.shader.prewarm": {"zh-Hans": "预热", "zh-Hant": "預熱",
                                       "ja": "プリウォーム", "ko": "프리워밍",
                                       "de": "Vorwärmen", "fr": "Préchauffage",
                                       "es": "Precalentamiento", "it": "Preriscaldamento",
                                       "pt-BR": "Pré-aquecimento", "pt-PT": "Pré-aquecimento",
                                       "ru": "Предварительный нагрев", "ar": "التسخين المسبق",
                                       "cs": "Předehřátí", "da": "Forvarmning",
                                       "fi": "Esilämmitys", "nl": "Voorverwarming",
                                       "pl": "Wstępne nagrzewanie", "ro": "Prelucrare",
                                       "tr": "Ön Isıtma", "uk": "Попереднє нагрівання",
                                       "vi": "Làm nóng trước"},
    }
    
    # Build the entry block
    lines = [f'    "{key}" : {{']
    lines.append('      "localizations" : {')
    
    lang_list = ["en", "zh-Hans", "zh-Hant", "ja", "ko", "de", "fr", "es", "it", 
                 "pt-BR", "pt-PT", "ru", "ar", "cs", "da", "fi", "nl", "pl", 
                 "ro", "tr", "uk", "vi"]
    
    for i, lang in enumerate(lang_list):
        value = trans.get(key, {}).get(lang) or en_value  # fallback to English
        lines.append(f'        "{lang}" : {{')
        lines.append('          "stringUnit" : {')
        lines.append('            "state" : "translated",')
        lines.append(f'            "value" : "{value}"')
        lines.append('          }')
        if i < len(lang_list) - 1:
            lines.append('        },')
        else:
            lines.append('        }')
    
    lines.append('      }')
    lines.append('    },')
    
    return '\n'.join(lines)

# Define all missing GPTK keys that need entries
keys_to_add = [
    ("config.gptk.compat.notes.count", "%d compatibility notes"),
    ("config.gptk.memory.auto", "Auto"),
    ("config.gptk.memory.limited", "Limited"),
    ("config.gptk.metrics.cpu", "CPU"),
    ("config.gptk.metrics.gpu", "GPU"),
    ("config.gptk.metrics.memory", "Memory"),
    ("config.gptk.metrics.refresh", "Refresh"),
    ("config.gptk.perf.balanced", "Balanced"),
    ("config.gptk.perf.performance", "Performance"),
    ("config.gptk.perf.quality", "Quality"),
    ("config.gptk.presets.count", "%d presets"),
    ("config.gptk.shader.compileOnLaunch", "Compile on Launch"),
    ("config.gptk.shader.disabled", "Disabled"),
    ("config.gptk.shader.prewarm", "Prewarm"),
]

# Build all entries
all_entries = []
for key, en_value in keys_to_add:
    entry = make_entry(key, en_value)
    all_entries.append(entry)

# Join with newlines between entries
combined = '\n'.join(all_entries)

# Find insertion point - right before "config.enhacnedSync.esync"
insertion_marker = '    "config.enhacnedSync.esync"'
if insertion_marker in content:
    # Insert all GPTK strings before this marker
    new_content = content.replace(insertion_marker, combined + '\n' + insertion_marker)
    
    # Write the modified content back to the file
    with open(xcstrings_path, 'w') as f:
        f.write(new_content)
    
    print(f"Added {len(keys_to_add)} remaining GPTK localization strings successfully!")
else:
    print(f"Could not find insertion marker: {insertion_marker}")

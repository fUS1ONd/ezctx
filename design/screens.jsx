// screens.jsx — 7 экранов приложения «Слух»

const { useState: useS } = React;

// ─── Обёртка экрана: device + wallpaper + динамические токены
function Phone({ dark, radius, children }) {
  // У IOSDevice есть свой фон — обнуляем через :first-child override
  return (
    <div className={`app ${dark ? "theme-dark" : ""}`} style={{
      "--r-card": `${radius}px`,
      "--r-row":  `${Math.max(8, radius - 6)}px`,
      "--r-tile": `${Math.max(16, radius + 8)}px`,
    }}>
      <IOSDevice dark={dark} width={390} height={844}>
        <div className={`wallpaper ${dark ? "dark" : "light"}`} />
        <div style={{ position: "absolute", inset: 0, zIndex: 1 }}>
          {children}
        </div>
      </IOSDevice>
    </div>
  );
}

// ════════════════════════════════════════════════════════
// 1. EMPTY STATE / ЗАГРУЗКА
// ════════════════════════════════════════════════════════
function ScreenEmpty({ dark, radius }) {
  return (
    <Phone dark={dark} radius={radius}>
      {/* шапка */}
      <div style={{ padding: "62px 20px 0", display: "flex", alignItems: "center", justifyContent: "space-between" }}>
        <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
          <div className="glass" style={{
            width: 36, height: 36, borderRadius: 11,
            display: "flex", alignItems: "center", justifyContent: "center",
            background: "linear-gradient(135deg, var(--accent-2), var(--accent))",
            color: "#fff",
          }}>
            <svg width="18" height="18" viewBox="0 0 18 18">
              <path d="M3 9h2M6 5v8M9 2v14M12 5v8M15 9h0" stroke="currentColor" strokeWidth="2" strokeLinecap="round" fill="none"/>
            </svg>
          </div>
          <div className="display" style={{ fontSize: 19 }}>Слух</div>
        </div>
        <GlassIconBtn>{Icon.gear(20)}</GlassIconBtn>
      </div>

      {/* большой заголовок */}
      <div style={{ padding: "32px 20px 0" }}>
        <div className="display" style={{ fontSize: 38, lineHeight: 1.04, letterSpacing: "-0.038em" }}>
          Расшифруй<br/>
          <span style={{
            background: "linear-gradient(120deg, var(--accent), #c93a8a 60%, #6a4adf)",
            WebkitBackgroundClip: "text", backgroundClip: "text",
            WebkitTextFillColor: "transparent",
          }}>любой звук</span>
        </div>
        <div style={{ marginTop: 10, fontSize: 16, color: "var(--ink-2)", lineHeight: 1.4 }}>
          Аудио и видео в текст за минуту. На устройстве остаётся только текст.
        </div>
      </div>

      {/* upload card */}
      <div style={{ padding: "28px 20px 0" }}>
        <div className="glass sheen" style={{
          borderRadius: "var(--r-tile)", padding: 28,
          display: "flex", flexDirection: "column", alignItems: "center", textAlign: "center",
          minHeight: 260, justifyContent: "center", gap: 14,
        }}>
          <div style={{
            width: 72, height: 72, borderRadius: 22,
            background: "linear-gradient(135deg, rgba(255,138,77,0.32), rgba(255,91,58,0.22))",
            border: "0.5px dashed rgba(255, 91, 58, 0.55)",
            display: "flex", alignItems: "center", justifyContent: "center",
            color: "var(--accent)",
          }}>
            {Icon.upload(34)}
          </div>
          <div style={{ fontSize: 18, fontWeight: 600 }}>Выберите файл</div>
          <div style={{ fontSize: 14, color: "var(--ink-2)", maxWidth: 240 }}>
            mp3, wav, m4a, ogg, flac<br/>mp4, mov, mkv — до 2 ГБ
          </div>
          <div style={{ display: "flex", gap: 10, marginTop: 8 }}>
            <GlassPill>📁 Из файлов</GlassPill>
            <GlassPill>☁️ iCloud</GlassPill>
          </div>
        </div>
      </div>

      {/* mic-кнопка primary */}
      <div style={{ padding: "16px 20px 0" }}>
        <PrimaryButton style={{ width: "100%", display: "flex", alignItems: "center", justifyContent: "center", gap: 10 }}>
          {Icon.mic(20)} Записать с микрофона
        </PrimaryButton>
      </div>

      <TabBar active="home" />
    </Phone>
  );
}

// ════════════════════════════════════════════════════════
// 2. ПРОЦЕСС — 5 этапов
// ════════════════════════════════════════════════════════
function ScreenProcess({ dark, radius }) {
  const stages = [
    { key: "upload",   label: "Загрузка",          sub: "12.4 МБ из 12.4 МБ",   state: "done"   },
    { key: "decode",   label: "Декодирование",     sub: "Извлечён моно-канал",  state: "done"   },
    { key: "asr",      label: "Распознавание речи",sub: "Whisper Large · groq", state: "active", percent: 64 },
    { key: "diar",     label: "Разделение по голосам", sub: "Ожидание",         state: "wait"   },
    { key: "done",     label: "Готово",            sub: "Финализация",          state: "wait"   },
  ];

  const dot = (st) => {
    if (st === "done") return (
      <div style={{
        width: 28, height: 28, borderRadius: 9999,
        background: "var(--good)", color: "#fff",
        display: "flex", alignItems: "center", justifyContent: "center",
      }}>{Icon.check(14)}</div>
    );
    if (st === "active") return (
      <div style={{
        width: 28, height: 28, borderRadius: 9999,
        background: "linear-gradient(135deg, var(--accent-2), var(--accent))",
        boxShadow: "0 0 0 6px rgba(255, 91, 58, 0.18)",
        display: "flex", alignItems: "center", justifyContent: "center",
      }}>
        <div style={{ display: "flex", gap: 2, color: "#fff" }}>
          {[0, 1, 2].map(i => (
            <div key={i} style={{
              width: 3, height: 3, borderRadius: 9999, background: "currentColor",
              animation: `pulseDot 1.2s ease-in-out ${i * 0.15}s infinite`,
            }}/>
          ))}
        </div>
      </div>
    );
    return (
      <div style={{
        width: 28, height: 28, borderRadius: 9999,
        border: "1.5px solid var(--ink-3)",
        background: "rgba(255,255,255,0.18)",
      }}/>
    );
  };

  return (
    <Phone dark={dark} radius={radius}>
      <ScreenHeader title="Обработка" big={false} right={<GlassIconBtn>{Icon.x(14)}</GlassIconBtn>} />

      {/* карточка файла */}
      <div style={{ padding: "0 16px" }}>
        <div className="glass sheen" style={{ borderRadius: "var(--r-tile)", padding: 18 }}>
          <div style={{ display: "flex", alignItems: "center", gap: 14 }}>
            <div style={{
              width: 56, height: 56, borderRadius: 16,
              background: "linear-gradient(135deg, #ff8a4d, #ff5b3a)",
              color: "#fff",
              display: "flex", alignItems: "center", justifyContent: "center",
            }}>{Icon.wave(28)}</div>
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ fontSize: 16, fontWeight: 600, overflow: "hidden",
                textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
                Звонок с заказчиком 14.05.mp3
              </div>
              <div className="mono" style={{ fontSize: 13, color: "var(--ink-2)", marginTop: 3 }}>
                42:18 · 12.4 МБ · 48 кГц
              </div>
            </div>
          </div>

          {/* большой прогресс-бар */}
          <div style={{ marginTop: 16, display: "flex", alignItems: "center", justifyContent: "space-between", marginBottom: 8 }}>
            <span style={{ fontSize: 13, color: "var(--ink-2)" }}>Распознавание речи</span>
            <span className="mono" style={{ fontSize: 13, fontWeight: 600 }}>64%</span>
          </div>
          <div style={{ height: 8, borderRadius: 9999, background: "var(--ink-line)", overflow: "hidden" }}>
            <div className="shimmer-bar" style={{ height: "100%", width: "64%", borderRadius: 9999 }} />
          </div>
          <div style={{ marginTop: 12, fontSize: 12, color: "var(--ink-3)" }}>
            Осталось около <span className="mono">1 мин 20 сек</span>
          </div>
        </div>
      </div>

      {/* этапы */}
      <div style={{ padding: "20px 16px 0" }}>
        <div style={{ fontSize: 12, fontWeight: 600, color: "var(--ink-3)",
          textTransform: "uppercase", letterSpacing: "0.08em",
          padding: "0 6px 10px" }}>Этапы</div>
        <div className="glass" style={{ borderRadius: "var(--r-card)", padding: "4px 0" }}>
          {stages.map((s, i) => (
            <div key={s.key} style={{
              display: "flex", alignItems: "center", gap: 14,
              padding: "12px 16px", position: "relative",
              opacity: s.state === "wait" ? 0.55 : 1,
            }}>
              {dot(s.state)}
              <div style={{ flex: 1 }}>
                <div style={{ fontSize: 15, fontWeight: 500 }}>{s.label}</div>
                <div style={{ fontSize: 12, color: "var(--ink-3)", marginTop: 2 }}>{s.sub}</div>
              </div>
              {/* вертикальный соединитель */}
              {i < stages.length - 1 && (
                <div style={{
                  position: "absolute", left: 16 + 13, top: 40, height: 18,
                  width: 1.5, borderRadius: 1,
                  background: (s.state === "done" ? "var(--good)" : "var(--ink-line)"),
                }}/>
              )}
            </div>
          ))}
        </div>
      </div>

      {/* нижняя кнопка */}
      <div style={{ position: "absolute", left: 16, right: 16, bottom: 30 }}>
        <div className="glass sheen" style={{
          borderRadius: 9999, padding: 6,
          display: "flex", alignItems: "center", justifyContent: "space-between",
        }}>
          <div style={{ padding: "0 16px", fontSize: 13, color: "var(--ink-2)" }}>
            <span className="mono" style={{ fontWeight: 600, color: "var(--ink)" }}>03:42</span> прошло
          </div>
          <div className="pill" style={{
            height: 44, padding: "0 18px",
            display: "flex", alignItems: "center", gap: 6,
            background: "rgba(224, 57, 90, 0.92)", color: "#fff",
            fontWeight: 600, fontSize: 14,
          }}>
            {Icon.x(12)} Отменить
          </div>
        </div>
      </div>
    </Phone>
  );
}

// ════════════════════════════════════════════════════════
// 3. ИСТОРИЯ — список расшифровок
// ════════════════════════════════════════════════════════
function ScreenHistory({ dark, radius }) {
  const items = [
    { name: "Звонок с заказчиком 14.05",  meta: "42:18 · сегодня, 14:22",   state: "active", percent: 64 },
    { name: "Интервью · Анна К.",          meta: "1 ч 12 мин · вчера",       state: "done"   },
    { name: "Встреча команды Q2-планы",   meta: "58:04 · 13 мая",            state: "done", words: 12483 },
    { name: "Лекция · нейросети",          meta: "2 ч 04 мин · 10 мая",      state: "done", words: 28114 },
    { name: "voice-memo-08.m4a",           meta: "03:11 · 8 мая",             state: "failed" },
    { name: "Подкаст · эпизод 14",         meta: "1 ч 38 мин · 5 мая",       state: "done", words: 21902 },
  ];

  const badge = (item) => {
    if (item.state === "active") return (
      <div className="pill" style={{
        padding: "5px 10px", fontSize: 11, fontWeight: 600,
        background: "rgba(255,91,58,0.18)", color: "var(--accent)",
        display: "flex", alignItems: "center", gap: 5,
      }}>
        <div style={{ display: "flex", gap: 1.5, alignItems: "center", height: 10 }}>
          {[0,1,2,3].map(i => (
            <div key={i} className="wave-bar" style={{
              height: "100%", animationDelay: `${i * 0.12}s`, width: 2,
            }}/>
          ))}
        </div>
        {item.percent}%
      </div>
    );
    if (item.state === "failed") return (
      <div className="pill" style={{
        padding: "5px 10px", fontSize: 11, fontWeight: 600,
        background: "rgba(224,57,90,0.18)", color: "var(--bad)",
        display: "flex", alignItems: "center", gap: 4,
      }}>{Icon.warn(11)} Ошибка</div>
    );
    return (
      <div style={{ fontSize: 12, color: "var(--ink-3)" }} className="mono">
        {item.words?.toLocaleString("ru")} слов
      </div>
    );
  };

  return (
    <Phone dark={dark} radius={radius}>
      {/* шапка */}
      <div style={{ padding: "62px 20px 8px", display: "flex", alignItems: "center", justifyContent: "space-between" }}>
        <div className="display" style={{ fontSize: 34, letterSpacing: "-0.035em" }}>Расшифровки</div>
        <GlassIconBtn size={44}>{Icon.plus(22)}</GlassIconBtn>
      </div>

      {/* поиск */}
      <div style={{ padding: "8px 16px 4px" }}>
        <div className="glass" style={{
          borderRadius: 9999, padding: "10px 14px",
          display: "flex", alignItems: "center", gap: 8, color: "var(--ink-2)",
        }}>
          {Icon.search(18)}
          <input style={{
            flex: 1, border: "none", outline: "none", background: "transparent",
            fontSize: 15, color: "var(--ink)", fontFamily: "inherit",
          }} placeholder="Найти в 27 расшифровках" defaultValue="" />
          <div style={{
            fontSize: 11, color: "var(--ink-3)",
            border: "0.5px solid var(--ink-line)", padding: "2px 6px",
            borderRadius: 4, fontWeight: 500,
          }}>⌘ F</div>
        </div>
      </div>

      {/* фильтры */}
      <div style={{ padding: "12px 16px 4px", display: "flex", gap: 8, overflowX: "auto" }}>
        <GlassPill active={true} style={{ padding: "6px 14px", fontSize: 13 }}>Все · 27</GlassPill>
        <GlassPill style={{ padding: "6px 14px", fontSize: 13 }}>Сегодня</GlassPill>
        <GlassPill style={{ padding: "6px 14px", fontSize: 13 }}>На этой неделе</GlassPill>
        <GlassPill style={{ padding: "6px 14px", fontSize: 13 }}>С ошибкой</GlassPill>
      </div>

      {/* список */}
      <div style={{ padding: "12px 16px 110px" }}>
        <div className="glass" style={{ borderRadius: "var(--r-card)", overflow: "hidden" }}>
          {items.map((it, i) => (
            <div key={i} style={{
              display: "flex", alignItems: "center", gap: 12,
              padding: "14px 14px", position: "relative",
            }}>
              <div style={{
                width: 42, height: 42, borderRadius: 12,
                background: it.state === "failed"
                  ? "linear-gradient(135deg, #ff9a9a, #e0395a)"
                  : it.state === "active"
                  ? "linear-gradient(135deg, #ff8a4d, #ff5b3a)"
                  : "linear-gradient(135deg, #9aa6ff, #6a4adf)",
                color: "#fff", flexShrink: 0,
                display: "flex", alignItems: "center", justifyContent: "center",
              }}>{Icon.wave(20)}</div>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontSize: 15, fontWeight: 600, lineHeight: 1.2,
                  overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
                  {it.name}
                </div>
                <div style={{ fontSize: 12, color: "var(--ink-3)", marginTop: 3 }} className="mono">
                  {it.meta}
                </div>
              </div>
              {badge(it)}
              {i < items.length - 1 && (
                <div style={{
                  position: "absolute", bottom: 0, left: 68, right: 14,
                  height: 0.5, background: "var(--ink-line)",
                }}/>
              )}
            </div>
          ))}
        </div>
      </div>

      <TabBar active="home" />
    </Phone>
  );
}

// ════════════════════════════════════════════════════════
// 4. ГОТОВАЯ РАСШИФРОВКА (деталь)
// ════════════════════════════════════════════════════════
function ScreenDetail({ dark, radius }) {
  const [copied, setCopied] = useS(false);
  return (
    <Phone dark={dark} radius={radius}>
      {/* nav */}
      <div style={{ padding: "62px 16px 12px", display: "flex", alignItems: "center", justifyContent: "space-between" }}>
        <GlassIconBtn>{Icon.back()}</GlassIconBtn>
        <div style={{ fontSize: 15, fontWeight: 600, color: "var(--ink-2)" }}>14 мая</div>
        <GlassIconBtn>{Icon.share(18)}</GlassIconBtn>
      </div>

      {/* meta */}
      <div style={{ padding: "8px 20px 0" }}>
        <div className="display" style={{ fontSize: 26, lineHeight: 1.12, letterSpacing: "-0.03em" }}>
          Интервью · Анна К.
        </div>
        <div className="mono" style={{ fontSize: 13, color: "var(--ink-2)", marginTop: 6 }}>
          1 ч 12 мин · 14 832 слова · 2 спикера
        </div>
      </div>

      {/* actions */}
      <div style={{ padding: "16px 16px 0", display: "flex", gap: 8 }}>
        <div onClick={() => { setCopied(true); setTimeout(() => setCopied(false), 1500); }}
          style={{
            flex: 1, height: 46, borderRadius: 14,
            background: copied
              ? "var(--good)"
              : "linear-gradient(180deg, var(--accent-2), var(--accent))",
            color: "#fff", fontWeight: 600, fontSize: 15,
            display: "flex", alignItems: "center", justifyContent: "center", gap: 8,
            boxShadow: "0 8px 18px rgba(255, 91, 58, 0.32), inset 0 0.5px 0 rgba(255,255,255,0.45)",
            cursor: "pointer",
          }}>
          {copied ? Icon.check(16) : Icon.copy(18)}
          {copied ? "Скопировано" : "Скопировать"}
        </div>
        <div className="glass" style={{
          height: 46, borderRadius: 14, padding: "0 16px",
          display: "flex", alignItems: "center", gap: 8,
          fontWeight: 600, fontSize: 14, color: "var(--ink-2)",
        }}>
          {Icon.sparkle(16)}
          <span>Спросить ИИ</span>
          <span style={{
            fontSize: 9, fontWeight: 700, letterSpacing: "0.06em",
            padding: "2px 6px", borderRadius: 4,
            background: "rgba(106,74,223,0.22)", color: "#6a4adf",
          }}>СКОРО</span>
        </div>
      </div>

      {/* плеер */}
      <div style={{ padding: "12px 16px 0" }}>
        <div className="glass" style={{ borderRadius: 18, padding: "10px 14px", display: "flex", alignItems: "center", gap: 12 }}>
          <div style={{
            width: 36, height: 36, borderRadius: 9999,
            background: "var(--ink)", color: dark ? "#1a1421" : "#fff",
            display: "flex", alignItems: "center", justifyContent: "center",
          }}>{Icon.play(13)}</div>
          {/* waveform */}
          <div style={{ flex: 1, display: "flex", alignItems: "center", gap: 1.5, height: 24, color: "var(--ink-3)" }}>
            {Array.from({ length: 60 }).map((_, i) => {
              const h = 4 + Math.abs(Math.sin(i * 0.7)) * 16 + (i % 4) * 1.5;
              const passed = i < 16;
              return (
                <div key={i} style={{
                  width: 2, height: `${Math.min(22, h)}px`, borderRadius: 1,
                  background: passed ? "var(--accent)" : "currentColor",
                  opacity: passed ? 1 : 0.45,
                }}/>
              );
            })}
          </div>
          <div className="mono" style={{ fontSize: 11, color: "var(--ink-2)", fontWeight: 600 }}>
            18:42 / 1:12:04
          </div>
        </div>
      </div>

      {/* текст */}
      <div style={{ padding: "16px 16px 30px" }}>
        <div className="glass" style={{ borderRadius: "var(--r-card)", padding: "18px 18px 22px" }}>
          <div style={{ display: "flex", gap: 10, alignItems: "baseline", marginBottom: 6 }}>
            <div style={{ fontSize: 13, fontWeight: 700, color: "var(--accent)" }}>А</div>
            <div className="mono" style={{ fontSize: 11, color: "var(--ink-3)" }}>00:00</div>
          </div>
          <div style={{ fontSize: 15, lineHeight: 1.55, color: "var(--ink)", textWrap: "pretty" }}>
            Спасибо, что нашли время. Давайте начнём с того, как вы пришли к идее этого продукта — что вообще подтолкнуло?
          </div>

          <div style={{ display: "flex", gap: 10, alignItems: "baseline", marginTop: 18, marginBottom: 6 }}>
            <div style={{ fontSize: 13, fontWeight: 700, color: "#6a4adf" }}>Б</div>
            <div className="mono" style={{ fontSize: 11, color: "var(--ink-3)" }}>00:14</div>
          </div>
          <div style={{ fontSize: 15, lineHeight: 1.55, color: "var(--ink)", textWrap: "pretty" }}>
            Если честно, всё началось с того, что я полгода каждое утро записывал голосовые заметки и не находил времени их перечитать. В какой-то момент стало понятно: нужен инструмент, который превращает разговор в текст без лишних кнопок.
          </div>

          <div style={{ display: "flex", gap: 10, alignItems: "baseline", marginTop: 18, marginBottom: 6 }}>
            <div style={{ fontSize: 13, fontWeight: 700, color: "var(--accent)" }}>А</div>
            <div className="mono" style={{ fontSize: 11, color: "var(--ink-3)" }}>00:42</div>
          </div>
          <div style={{ fontSize: 15, lineHeight: 1.55, color: "var(--ink)", textWrap: "pretty" }}>
            То есть фокус был не на распознавании самом по себе, а на пути от записи до полезной мысли?
          </div>
        </div>
      </div>
    </Phone>
  );
}

// ════════════════════════════════════════════════════════
// 5. НАСТРОЙКИ (главная)
// ════════════════════════════════════════════════════════
function ScreenSettings({ dark, radius }) {
  return (
    <Phone dark={dark} radius={radius}>
      <div style={{ padding: "62px 20px 8px" }}>
        <div className="display" style={{ fontSize: 34, letterSpacing: "-0.035em" }}>Настройки</div>
      </div>

      {/* карточка статуса */}
      <div style={{ padding: "12px 16px 0" }}>
        <div className="glass sheen" style={{ borderRadius: "var(--r-tile)", padding: 18, display: "flex", alignItems: "center", gap: 14 }}>
          <div style={{
            width: 48, height: 48, borderRadius: 14,
            background: "linear-gradient(135deg, var(--accent-2), var(--accent))",
            color: "#fff", display: "flex", alignItems: "center", justifyContent: "center",
            fontWeight: 700, fontSize: 18,
          }}>С</div>
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 16, fontWeight: 600 }}>Подключено к Groq</div>
            <div style={{ fontSize: 13, color: "var(--ink-2)", marginTop: 2 }}>
              <span style={{ color: "var(--good)" }}>●</span>{" "}
              whisper-large-v3 · 2,4 ч в этом месяце
            </div>
          </div>
        </div>
      </div>

      {/* группа: подключение */}
      <div style={{ padding: "22px 0 0" }}>
        <div style={{ fontSize: 12, fontWeight: 600, color: "var(--ink-3)",
          textTransform: "uppercase", letterSpacing: "0.08em",
          padding: "0 30px 8px" }}>Подключение</div>
        <ListCard>
          <ListRow icon={Icon.key(18)} iconBg="linear-gradient(135deg, #ff8a4d, #ff5b3a)" title="API-ключи" detail="1 активен" />
          <ListRow icon={Icon.wave(18)} iconBg="linear-gradient(135deg, #9aa6ff, #6a4adf)" title="Модель" detail="Whisper Large v3" />
          <ListRow icon={
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none">
              <circle cx="12" cy="12" r="9" stroke="currentColor" strokeWidth="1.8"/>
              <path d="M3 12h18M12 3a14 14 0 0 1 0 18M12 3a14 14 0 0 0 0 18" stroke="currentColor" strokeWidth="1.8"/>
            </svg>
          } iconBg="linear-gradient(135deg, #5dd1b5, #2db585)" title="Язык распознавания" detail="Русский" isLast />
        </ListCard>
      </div>

      {/* группа: приложение */}
      <div style={{ padding: "26px 0 0" }}>
        <div style={{ fontSize: 12, fontWeight: 600, color: "var(--ink-3)",
          textTransform: "uppercase", letterSpacing: "0.08em",
          padding: "0 30px 8px" }}>Приложение</div>
        <ListCard>
          <ListRow icon={
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none">
              <circle cx="12" cy="12" r="4" stroke="currentColor" strokeWidth="1.8"/>
              <path d="M12 2v3M12 19v3M22 12h-3M5 12H2M19 5l-2 2M7 17l-2 2M19 19l-2-2M7 7L5 5" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round"/>
            </svg>
          } iconBg="linear-gradient(135deg, #ffe78a, #ffb74d)" title="Внешний вид" detail="Автоматически" />
          <ListRow icon={
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none">
              <path d="M21 15a2 2 0 0 1-2 2H8l-5 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2v10z" stroke="currentColor" strokeWidth="1.8"/>
            </svg>
          } iconBg="linear-gradient(135deg, #ff9aa6, #c93a8a)" title="Уведомления" detail="Включены" />
          <ListRow icon={
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none">
              <path d="M12 22s-7-4-7-12V5l7-3 7 3v5c0 8-7 12-7 12z" stroke="currentColor" strokeWidth="1.8"/>
            </svg>
          } iconBg="linear-gradient(135deg, #8ad0ff, #4a8aff)" title="Конфиденциальность" isLast />
        </ListCard>
      </div>

      {/* служебные */}
      <div style={{ padding: "26px 0 130px" }}>
        <ListCard>
          <ListRow title="О приложении" detail="2.1.0 (412)" />
          <ListRow title="Сообщить о проблеме" />
          <ListRow title="Выйти из аккаунта" danger isLast />
        </ListCard>
      </div>

      <TabBar active="set" />
    </Phone>
  );
}

// ════════════════════════════════════════════════════════
// 6. API-КЛЮЧИ (Groq)
// ════════════════════════════════════════════════════════
function ScreenApiKeys({ dark, radius }) {
  return (
    <Phone dark={dark} radius={radius}>
      <ScreenHeader title="API-ключи" big={false} />

      {/* hero-карточка Groq */}
      <div style={{ padding: "8px 16px 0" }}>
        <div className="glass sheen" style={{
          borderRadius: "var(--r-tile)", padding: 22,
          display: "flex", flexDirection: "column", gap: 16,
        }}>
          <div style={{ display: "flex", alignItems: "center", gap: 14 }}>
            {/* groq mark — заглушка-логотип */}
            <div style={{
              width: 52, height: 52, borderRadius: 16,
              background: "linear-gradient(135deg, #ff8a4d, #ff5b3a 60%, #c93a5a)",
              color: "#fff",
              display: "flex", alignItems: "center", justifyContent: "center",
              fontWeight: 800, fontSize: 22, letterSpacing: "-0.04em",
              boxShadow: "inset 0 0.5px 0 rgba(255,255,255,0.4), 0 6px 14px rgba(255, 91, 58, 0.32)",
            }}>q</div>
            <div style={{ flex: 1 }}>
              <div style={{ fontSize: 18, fontWeight: 700, letterSpacing: "-0.01em" }}>Groq</div>
              <div style={{ fontSize: 13, color: "var(--ink-2)", marginTop: 2 }}>
                Распознавание через Whisper · самый быстрый инференс
              </div>
            </div>
            <div className="pill" style={{
              padding: "5px 10px", fontSize: 11, fontWeight: 700, letterSpacing: "0.04em",
              background: "rgba(45,181,133,0.18)", color: "var(--good)",
              display: "flex", alignItems: "center", gap: 5,
            }}>
              <span style={{ width: 6, height: 6, borderRadius: 9999, background: "var(--good)" }}/>
              ПОДКЛЮЧЕНО
            </div>
          </div>

          {/* поле ключа */}
          <div>
            <div style={{ fontSize: 12, fontWeight: 600, color: "var(--ink-3)",
              textTransform: "uppercase", letterSpacing: "0.08em", marginBottom: 8 }}>
              API ключ
            </div>
            <div style={{
              background: "rgba(0,0,0,0.05)", borderRadius: 14,
              padding: "12px 14px", display: "flex", alignItems: "center", gap: 10,
              border: "0.5px solid var(--ink-line)",
            }}>
              <span className="mono" style={{ fontSize: 13.5, color: "var(--ink)", flex: 1, letterSpacing: "-0.02em" }}>
                gsk_••••••••••••••••••••••3A2f
              </span>
              <div style={{ color: "var(--ink-2)", cursor: "pointer" }}>{Icon.eye(16)}</div>
              <div style={{ color: "var(--ink-2)", cursor: "pointer" }}>{Icon.copy(16)}</div>
            </div>
            <div style={{ fontSize: 12, color: "var(--ink-3)", marginTop: 8, lineHeight: 1.45 }}>
              Добавлен 2 мая. Ключ хранится в Связке ключей iCloud и не передаётся на наши серверы.
            </div>
          </div>

          {/* действия */}
          <div style={{ display: "flex", gap: 8 }}>
            <div className="glass pill" style={{
              flex: 1, height: 42, fontSize: 14, fontWeight: 600,
              display: "flex", alignItems: "center", justifyContent: "center", gap: 6,
            }}>
              {Icon.refresh(15)} Проверить
            </div>
            <div className="glass pill" style={{
              flex: 1, height: 42, fontSize: 14, fontWeight: 600,
              display: "flex", alignItems: "center", justifyContent: "center", gap: 6,
              color: "var(--bad)",
            }}>
              {Icon.trash(15)} Удалить
            </div>
          </div>
        </div>
      </div>

      {/* статистика */}
      <div style={{ padding: "18px 16px 0" }}>
        <div className="glass" style={{ borderRadius: "var(--r-card)", padding: 16,
          display: "grid", gridTemplateColumns: "1fr 1fr 1fr", gap: 12 }}>
          {[
            ["Запросов", "1 248"],
            ["Часов", "12,8"],
            ["За месяц", "$3.41"],
          ].map(([k, v]) => (
            <div key={k}>
              <div className="mono display" style={{ fontSize: 22, letterSpacing: "-0.04em" }}>{v}</div>
              <div style={{ fontSize: 11, color: "var(--ink-3)", marginTop: 2,
                textTransform: "uppercase", letterSpacing: "0.06em" }}>{k}</div>
            </div>
          ))}
        </div>
      </div>

      {/* инфо */}
      <div style={{ padding: "18px 16px 30px" }}>
        <div style={{
          background: "rgba(106,74,223,0.10)",
          border: "0.5px solid rgba(106,74,223,0.20)",
          borderRadius: 18, padding: "14px 16px",
          display: "flex", gap: 12, alignItems: "flex-start",
        }}>
          <div style={{ color: "#6a4adf", flexShrink: 0, marginTop: 1 }}>
            {Icon.sparkle(16)}
          </div>
          <div style={{ fontSize: 13, lineHeight: 1.5, color: "var(--ink-2)" }}>
            Ключ можно получить в <span style={{ color: "#6a4adf", fontWeight: 600 }}>console.groq.com → API Keys</span>.
            Бесплатного тира хватит примерно на 15 часов аудио в день.
          </div>
        </div>
      </div>
    </Phone>
  );
}

// ════════════════════════════════════════════════════════
// 7. ОШИБКА
// ════════════════════════════════════════════════════════
function ScreenError({ dark, radius }) {
  return (
    <Phone dark={dark} radius={radius}>
      <ScreenHeader title="Расшифровка" big={false} right={<GlassIconBtn>{Icon.x(14)}</GlassIconBtn>} />

      {/* hero ошибки */}
      <div style={{ padding: "20px 20px 0", textAlign: "center" }}>
        <div style={{
          width: 96, height: 96, margin: "0 auto", borderRadius: 28,
          background: "linear-gradient(135deg, #ffb3c4, #e0395a)",
          color: "#fff",
          display: "flex", alignItems: "center", justifyContent: "center",
          boxShadow: "inset 0 1px 0 rgba(255,255,255,0.4), 0 14px 32px rgba(224, 57, 90, 0.34)",
        }}>
          <svg width="44" height="44" viewBox="0 0 24 24" fill="none">
            <path d="M12 3l10 18H2L12 3z" stroke="currentColor" strokeWidth="2" strokeLinejoin="round"/>
            <path d="M12 10v5M12 18v.5" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round"/>
          </svg>
        </div>

        <div className="display" style={{ fontSize: 26, marginTop: 22, letterSpacing: "-0.03em", lineHeight: 1.15 }}>
          Не удалось расшифровать
        </div>
        <div style={{ fontSize: 15, color: "var(--ink-2)", marginTop: 10, lineHeight: 1.45, padding: "0 8px" }}>
          На этапе распознавания речи прервалось соединение с Groq. Файл сохранён, ничего не потеряно.
        </div>
      </div>

      {/* detail-карточка с этапом */}
      <div style={{ padding: "24px 16px 0" }}>
        <div className="glass" style={{ borderRadius: "var(--r-card)", padding: "14px 16px" }}>
          <div style={{ display: "flex", alignItems: "center", gap: 12, marginBottom: 10 }}>
            <div style={{
              width: 36, height: 36, borderRadius: 11,
              background: "linear-gradient(135deg, #ff8a4d, #ff5b3a)",
              color: "#fff", display: "flex", alignItems: "center", justifyContent: "center",
            }}>{Icon.wave(18)}</div>
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ fontSize: 14, fontWeight: 600, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
                voice-memo-08.m4a
              </div>
              <div className="mono" style={{ fontSize: 12, color: "var(--ink-3)" }}>03:11 · 8 мая, 11:04</div>
            </div>
          </div>

          {/* код ошибки */}
          <div style={{
            background: "rgba(224,57,90,0.10)", borderRadius: 12,
            padding: "10px 12px", display: "flex", alignItems: "center", gap: 10,
            border: "0.5px solid rgba(224,57,90,0.22)",
          }}>
            <div style={{ color: "var(--bad)", flexShrink: 0 }}>{Icon.warn(16)}</div>
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ fontSize: 13, fontWeight: 600, color: "var(--bad)" }}>
                NetworkError · после 7 минут
              </div>
              <div className="mono" style={{ fontSize: 11, color: "var(--ink-2)", marginTop: 2,
                overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
                groq.com/v1/audio/transcriptions → ECONNRESET
              </div>
            </div>
          </div>

          {/* mini-stages */}
          <div style={{ marginTop: 14, display: "flex", alignItems: "center", gap: 4 }}>
            {[
              { label: "Загрузка", ok: true },
              { label: "Декод.",   ok: true },
              { label: "ASR",      ok: false },
              { label: "Диариз.",  ok: null },
              { label: "Готово",   ok: null },
            ].map((st, i) => (
              <React.Fragment key={i}>
                <div style={{
                  flex: 1, height: 4, borderRadius: 9999,
                  background: st.ok === true ? "var(--good)"
                            : st.ok === false ? "var(--bad)"
                            : "var(--ink-line)",
                }} />
                {i < 4 && <div style={{ width: 0 }}/>}
              </React.Fragment>
            ))}
          </div>
          <div style={{ display: "flex", justifyContent: "space-between", marginTop: 6,
            fontSize: 10, color: "var(--ink-3)", letterSpacing: "0.04em" }}>
            <span>✓ Загр.</span>
            <span>✓ Декод.</span>
            <span style={{ color: "var(--bad)", fontWeight: 600 }}>✕ ASR</span>
            <span>· Диариз.</span>
            <span>· Готово</span>
          </div>
        </div>
      </div>

      {/* действия */}
      <div style={{ position: "absolute", left: 16, right: 16, bottom: 30,
        display: "flex", flexDirection: "column", gap: 10 }}>
        <PrimaryButton style={{ width: "100%", display: "flex", alignItems: "center", justifyContent: "center", gap: 10 }}>
          {Icon.refresh(18)} Повторить
        </PrimaryButton>
        <div style={{ display: "flex", gap: 8 }}>
          <div className="glass pill" style={{
            flex: 1, height: 46, fontSize: 14, fontWeight: 600,
            display: "flex", alignItems: "center", justifyContent: "center", gap: 6,
          }}>
            Сообщить об ошибке
          </div>
          <div className="glass pill" style={{
            flex: 1, height: 46, fontSize: 14, fontWeight: 600,
            display: "flex", alignItems: "center", justifyContent: "center", gap: 6,
            color: "var(--bad)",
          }}>
            {Icon.trash(15)} Удалить
          </div>
        </div>
      </div>
    </Phone>
  );
}

Object.assign(window, {
  ScreenEmpty, ScreenProcess, ScreenHistory, ScreenDetail,
  ScreenSettings, ScreenApiKeys, ScreenError,
});

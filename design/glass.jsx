// glass.jsx — переиспользуемые стеклянные примитивы
// Иконки и кнопки в стиле Liquid Glass

const { useState } = React;

// ─── Иконки (минимальный набор, SF Symbols-like) ─────────
const Icon = {
  upload: (s = 24) => (
    <svg width={s} height={s} viewBox="0 0 24 24" fill="none">
      <path d="M12 16V4M12 4l-5 5M12 4l5 5" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"/>
      <path d="M5 18v1a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2v-1" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round"/>
    </svg>
  ),
  mic: (s = 24) => (
    <svg width={s} height={s} viewBox="0 0 24 24" fill="none">
      <rect x="9" y="3" width="6" height="12" rx="3" stroke="currentColor" strokeWidth="1.8"/>
      <path d="M6 11a6 6 0 0 0 12 0M12 17v4M9 21h6" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round"/>
    </svg>
  ),
  wave: (s = 24) => (
    <svg width={s} height={s} viewBox="0 0 24 24" fill="none">
      <path d="M3 12h2M7 8v8M11 5v14M15 8v8M19 11v2M21 12h0" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round"/>
    </svg>
  ),
  copy: (s = 20) => (
    <svg width={s} height={s} viewBox="0 0 24 24" fill="none">
      <rect x="8" y="8" width="12" height="12" rx="3" stroke="currentColor" strokeWidth="1.8"/>
      <path d="M16 8V6a2 2 0 0 0-2-2H6a2 2 0 0 0-2 2v8a2 2 0 0 0 2 2h2" stroke="currentColor" strokeWidth="1.8"/>
    </svg>
  ),
  sparkle: (s = 20) => (
    <svg width={s} height={s} viewBox="0 0 24 24" fill="none">
      <path d="M12 3v4M12 17v4M3 12h4M17 12h4M5.6 5.6l2.8 2.8M15.6 15.6l2.8 2.8M5.6 18.4l2.8-2.8M15.6 8.4l2.8-2.8" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round"/>
    </svg>
  ),
  share: (s = 20) => (
    <svg width={s} height={s} viewBox="0 0 24 24" fill="none">
      <path d="M12 3v13M12 3l-4 4M12 3l4 4" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"/>
      <path d="M6 12H5a2 2 0 0 0-2 2v5a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-5a2 2 0 0 0-2-2h-1" stroke="currentColor" strokeWidth="1.8"/>
    </svg>
  ),
  search: (s = 20) => (
    <svg width={s} height={s} viewBox="0 0 24 24" fill="none">
      <circle cx="11" cy="11" r="7" stroke="currentColor" strokeWidth="1.8"/>
      <path d="M16 16l4.5 4.5" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round"/>
    </svg>
  ),
  chevron: (s = 14) => (
    <svg width={s} height={s} viewBox="0 0 14 14" fill="none">
      <path d="M5 2l5 5-5 5" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
    </svg>
  ),
  back: (s = 18) => (
    <svg width={s} height={s} viewBox="0 0 18 18" fill="none">
      <path d="M11 3L4 9l7 6" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round"/>
    </svg>
  ),
  check: (s = 16) => (
    <svg width={s} height={s} viewBox="0 0 16 16" fill="none">
      <path d="M3 8.5l3.5 3.5L13 5" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round"/>
    </svg>
  ),
  warn: (s = 20) => (
    <svg width={s} height={s} viewBox="0 0 24 24" fill="none">
      <path d="M12 3l10 18H2L12 3z" stroke="currentColor" strokeWidth="1.8" strokeLinejoin="round"/>
      <path d="M12 10v5M12 18v.5" stroke="currentColor" strokeWidth="2" strokeLinecap="round"/>
    </svg>
  ),
  plus: (s = 20) => (
    <svg width={s} height={s} viewBox="0 0 24 24" fill="none">
      <path d="M12 5v14M5 12h14" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round"/>
    </svg>
  ),
  gear: (s = 22) => (
    <svg width={s} height={s} viewBox="0 0 24 24" fill="none">
      <circle cx="12" cy="12" r="3" stroke="currentColor" strokeWidth="1.8"/>
      <path d="M12 2v3M12 19v3M22 12h-3M5 12H2M19 5l-2 2M7 17l-2 2M19 19l-2-2M7 7L5 5" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round"/>
    </svg>
  ),
  key: (s = 22) => (
    <svg width={s} height={s} viewBox="0 0 24 24" fill="none">
      <circle cx="8" cy="14" r="4.5" stroke="currentColor" strokeWidth="1.8"/>
      <path d="M11.2 11.5L20 3M16.5 6.5l2 2M18 5l2 2" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"/>
    </svg>
  ),
  eye: (s = 18) => (
    <svg width={s} height={s} viewBox="0 0 24 24" fill="none">
      <path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7S2 12 2 12z" stroke="currentColor" strokeWidth="1.6"/>
      <circle cx="12" cy="12" r="2.5" stroke="currentColor" strokeWidth="1.6"/>
    </svg>
  ),
  trash: (s = 18) => (
    <svg width={s} height={s} viewBox="0 0 24 24" fill="none">
      <path d="M4 7h16M9 7V5a2 2 0 0 1 2-2h2a2 2 0 0 1 2 2v2M6 7l1 13a2 2 0 0 0 2 2h6a2 2 0 0 0 2-2l1-13" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round"/>
    </svg>
  ),
  refresh: (s = 18) => (
    <svg width={s} height={s} viewBox="0 0 24 24" fill="none">
      <path d="M20 12a8 8 0 1 1-2.5-5.8L20 4M20 4v5h-5" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"/>
    </svg>
  ),
  doc: (s = 22) => (
    <svg width={s} height={s} viewBox="0 0 24 24" fill="none">
      <path d="M6 3h8l5 5v11a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2z" stroke="currentColor" strokeWidth="1.6"/>
      <path d="M14 3v5h5M8 13h8M8 17h6" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round"/>
    </svg>
  ),
  play: (s = 16) => (
    <svg width={s} height={s} viewBox="0 0 16 16" fill="currentColor">
      <path d="M4 2.5L13 8 4 13.5V2.5z"/>
    </svg>
  ),
  pause: (s = 16) => (
    <svg width={s} height={s} viewBox="0 0 16 16" fill="currentColor">
      <rect x="4" y="2.5" width="3" height="11" rx="1"/>
      <rect x="9" y="2.5" width="3" height="11" rx="1"/>
    </svg>
  ),
  x: (s = 16) => (
    <svg width={s} height={s} viewBox="0 0 16 16" fill="none">
      <path d="M3 3l10 10M13 3L3 13" stroke="currentColor" strokeWidth="2" strokeLinecap="round"/>
    </svg>
  ),
};

// ─── Glass-капсула (мини, для тулбара/чипов) ─────────────
function GlassPill({ children, style = {}, onClick, active = false }) {
  return (
    <div className="glass pill" onClick={onClick} style={{
      display: "inline-flex", alignItems: "center", gap: 6,
      padding: "8px 14px", fontSize: 14, fontWeight: 500,
      cursor: onClick ? "pointer" : "default",
      background: active ? "rgba(255, 91, 58, 0.92)" : undefined,
      color: active ? "#fff" : "var(--ink)",
      ...style,
    }}>
      {children}
    </div>
  );
}

// ─── Иконочная кнопка-капсула в стиле iOS 26 ─────────────
function GlassIconBtn({ children, size = 40, style = {}, onClick }) {
  return (
    <div className="glass" onClick={onClick} style={{
      width: size, height: size, borderRadius: 9999,
      display: "flex", alignItems: "center", justifyContent: "center",
      color: "var(--ink)", cursor: onClick ? "pointer" : "default",
      flexShrink: 0,
      ...style,
    }}>
      {children}
    </div>
  );
}

// ─── Заметная primary-кнопка (заливка) ───────────────────
function PrimaryButton({ children, style = {}, onClick }) {
  return (
    <button onClick={onClick} style={{
      appearance: "none", border: "none",
      background: "linear-gradient(180deg, var(--accent-2), var(--accent))",
      color: "#fff", fontWeight: 600, fontSize: 17,
      height: 54, borderRadius: "var(--r-row)",
      padding: "0 24px", cursor: "pointer",
      letterSpacing: "-0.01em",
      boxShadow:
        "inset 0 0.5px 0 rgba(255,255,255,0.5)," +
        "inset 0 -1px 0 rgba(0,0,0,0.15)," +
        "0 10px 24px rgba(255, 91, 58, 0.34)," +
        "0 1px 2px rgba(0,0,0,0.10)",
      fontFamily: "inherit",
      ...style,
    }}>{children}</button>
  );
}

// ─── Шапка экрана: back + title + (опц. action) ──────────
function ScreenHeader({ title, onBack = true, right = null, big = true }) {
  return (
    <div style={{
      padding: "62px 16px 12px",
      display: "flex", flexDirection: "column", gap: big ? 14 : 0,
      position: "relative",
    }}>
      <div style={{
        display: "flex", alignItems: "center", justifyContent: "space-between",
        height: 40,
      }}>
        {onBack ? (
          <GlassIconBtn>
            {Icon.back()}
          </GlassIconBtn>
        ) : <div style={{ width: 40 }} />}
        {right || <div style={{ width: 40 }} />}
      </div>
      {big ? (
        <div className="display" style={{ fontSize: 34, lineHeight: 1.08 }}>
          {title}
        </div>
      ) : (
        <div className="display" style={{
          fontSize: 17, fontWeight: 600,
          position: "absolute", left: 0, right: 0, top: 62, height: 40,
          display: "flex", alignItems: "center", justifyContent: "center",
          pointerEvents: "none",
        }}>
          {title}
        </div>
      )}
    </div>
  );
}

// ─── Вкладочная навигация снизу (3 таба) ─────────────────
function TabBar({ active = "home" }) {
  const tabs = [
    { id: "home",    label: "Расшифровки", icon: Icon.wave(22) },
    { id: "history", label: "История",     icon: Icon.doc(22) },
    { id: "set",     label: "Настройки",   icon: Icon.gear(22) },
  ];
  return (
    <div style={{
      position: "absolute", left: 16, right: 16, bottom: 30,
      zIndex: 30,
    }}>
      <div className="glass sheen" style={{
        borderRadius: 9999, padding: 6,
        display: "flex", alignItems: "center", justifyContent: "space-between",
      }}>
        {tabs.map(t => {
          const on = t.id === active;
          return (
            <div key={t.id} style={{
              flex: 1, height: 48, borderRadius: 9999,
              display: "flex", alignItems: "center", justifyContent: "center", gap: 6,
              background: on ? "rgba(255, 91, 58, 0.92)" : "transparent",
              color: on ? "#fff" : "var(--ink-2)",
              fontWeight: on ? 600 : 500, fontSize: 13,
              boxShadow: on
                ? "inset 0 0.5px 0 rgba(255,255,255,0.45), 0 4px 12px rgba(255, 91, 58, 0.34)"
                : "none",
              transition: "all .18s",
            }}>
              {t.icon}
              <span>{t.label}</span>
            </div>
          );
        })}
      </div>
    </div>
  );
}

// ─── Карточка-блок секции (как iOS inset-grouped list) ───
function ListCard({ children, style = {} }) {
  return (
    <div className="glass" style={{
      borderRadius: 22, overflow: "hidden", margin: "0 16px",
      ...style,
    }}>
      {children}
    </div>
  );
}

function ListRow({ icon, iconBg, title, detail, sub, right, isLast = false, danger = false }) {
  return (
    <div style={{
      display: "flex", alignItems: "center", gap: 12,
      padding: "14px 16px", position: "relative",
      color: danger ? "var(--bad)" : "var(--ink)",
    }}>
      {icon && (
        <div style={{
          width: 32, height: 32, borderRadius: 9,
          background: iconBg || "rgba(255, 91, 58, 0.18)",
          color: iconBg ? "#fff" : "var(--accent)",
          display: "flex", alignItems: "center", justifyContent: "center",
          flexShrink: 0,
        }}>{icon}</div>
      )}
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontSize: 16, fontWeight: 500, letterSpacing: "-0.01em",
          overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>{title}</div>
        {sub && <div style={{ fontSize: 13, color: "var(--ink-3)", marginTop: 2 }}>{sub}</div>}
      </div>
      {detail && <span style={{ fontSize: 15, color: "var(--ink-3)" }}>{detail}</span>}
      {right ?? null}
      {!isLast && (
        <div style={{
          position: "absolute", bottom: 0, left: icon ? 60 : 16, right: 0,
          height: 0.5, background: "var(--ink-line)",
        }} />
      )}
    </div>
  );
}

Object.assign(window, {
  Icon, GlassPill, GlassIconBtn, PrimaryButton, ScreenHeader, TabBar, ListCard, ListRow,
});

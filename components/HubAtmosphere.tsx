export function HubAtmosphere() {
  return (
    <div
      aria-hidden
      className="pointer-events-none fixed inset-0 -z-10 overflow-hidden"
    >
      <div className="absolute -left-14 top-72 h-36 w-24 rounded-[60%_40%_55%_45%] bg-[var(--pink)]" />
      <div className="absolute -right-12 top-44 h-20 w-36 rounded-full bg-[var(--orange)]" />
      <div className="absolute top-[48%] -left-4 h-10 w-10 rounded-full bg-[var(--violet)]" />
      <div className="absolute right-[-28px] bottom-24 h-28 w-40 rounded-[55%_45%_60%_40%] bg-[var(--aqua)]" />
      <div className="absolute bottom-10 -left-3 h-8 w-14 rounded-full bg-[var(--pink)]/90" />
      <svg
        className="absolute bottom-[-80px] left-1/2 h-[420px] w-[420px] -translate-x-1/2 opacity-25"
        viewBox="0 0 400 520"
        fill="none"
        stroke="white"
        strokeWidth="1.25"
      >
        <ellipse cx="200" cy="230" rx="150" ry="190" />
        <ellipse cx="206" cy="214" rx="78" ry="112" />
        <ellipse cx="248" cy="250" rx="46" ry="28" />
        <circle cx="262" cy="150" r="16" />
        <circle cx="150" cy="360" r="22" />
        <path d="M120 180 C 160 140, 230 120, 280 150" />
        <path d="M150 360 C 180 300, 230 280, 250 250" />
      </svg>
    </div>
  );
}

"use client";

import { useEffect, useRef, useState, useSyncExternalStore } from "react";
import {
  CUSTOM_STOPS,
  DEFAULT_CUSTOM_INDEX,
  START_GRASS,
  STORAGE_KEY,
  applyGrassChange,
  formatDelta,
  formatGrass,
  readSavedGrass,
  savedGrassPayload,
} from "./counter";
import { mountLawn, type LawnView } from "./scene";

type Props = {
  slug: string;
};

const ADD_STEPS = [1_000, 10_000, 100_000] as const;
const REMOVE_STEPS = [1_000, 10_000, 100_000] as const;

function subscribeSaved(onChange: () => void) {
  window.addEventListener("storage", onChange);
  return () => window.removeEventListener("storage", onChange);
}

function readSavedRaw(): string | null {
  try {
    return localStorage.getItem(STORAGE_KEY);
  } catch {
    return null;
  }
}

function noSaved(): null {
  return null;
}

export function LawnCanvas({ slug }: Props) {
  const rootRef = useRef<HTMLDivElement>(null);
  const viewRef = useRef<LawnView | null>(null);
  const grassRef = useRef(START_GRASS);
  const countingRef = useRef(false);
  const timerRef = useRef<number | null>(null);
  const deltaSerial = useRef(0);

  const storedRaw = useSyncExternalStore(subscribeSaved, readSavedRaw, noSaved);
  const [seenRaw, setSeenRaw] = useState<string | null>(null);
  const [grass, setGrass] = useState(START_GRASS);
  const [checkpoint, setCheckpoint] = useState<number | null>(null);
  const [customIndex, setCustomIndex] = useState(DEFAULT_CUSTOM_INDEX);
  const [countdown, setCountdown] = useState<number | null>(null);
  const [delta, setDelta] = useState<{ id: number; applied: number } | null>(
    null,
  );
  const [saveNote, setSaveNote] = useState<string | null>(null);

  if (storedRaw !== seenRaw) {
    setSeenRaw(storedRaw);
    const savedGrass = readSavedGrass(storedRaw);
    if (savedGrass != null) {
      setGrass(savedGrass);
      setCheckpoint(savedGrass);
    }
  }

  const custom = CUSTOM_STOPS[customIndex] ?? CUSTOM_STOPS[DEFAULT_CUSTOM_INDEX];
  const locked = countdown !== null;
  const saved = checkpoint === grass;

  function clearTimer() {
    if (timerRef.current != null) {
      window.clearInterval(timerRef.current);
      timerRef.current = null;
    }
    countingRef.current = false;
  }

  function commit(next: number, applied: number) {
    grassRef.current = next;
    setGrass(next);
    if (applied === 0) return;
    const id = ++deltaSerial.current;
    setDelta({ id, applied });
    window.setTimeout(() => {
      setDelta((current) => (current && current.id === id ? null : current));
    }, 1150);
  }

  function changeBy(amount: number) {
    if (countingRef.current) return;
    const { grass: next, applied } = applyGrassChange(grassRef.current, amount);
    commit(next, applied);
  }

  function finishReset() {
    const { grass: next, applied } = applyGrassChange(
      grassRef.current,
      START_GRASS - grassRef.current,
    );
    commit(next, applied);
  }

  function startCountdown() {
    if (countingRef.current) return;
    countingRef.current = true;
    let left = 3;
    setCountdown(3);
    timerRef.current = window.setInterval(() => {
      left -= 1;
      if (left <= 0) {
        clearTimer();
        setCountdown(null);
        finishReset();
        return;
      }
      setCountdown(left);
    }, 1000);
  }

  function instantReset() {
    clearTimer();
    setCountdown(null);
    finishReset();
  }

  function save() {
    try {
      localStorage.setItem(STORAGE_KEY, savedGrassPayload(grassRef.current));
      setCheckpoint(grassRef.current);
      setSaveNote(null);
    } catch {
      setSaveNote("Couldn't save in this browser");
    }
  }

  useEffect(() => {
    grassRef.current = grass;
  }, [grass]);

  useEffect(() => {
    const root = rootRef.current;
    if (!root) return;
    const view = mountLawn(root);
    viewRef.current = view;
    view.apply(grassRef.current);
    return () => {
      view.dispose();
      viewRef.current = null;
    };
  }, []);

  useEffect(() => {
    viewRef.current?.apply(grass);
  }, [grass]);

  useEffect(() => {
    const es = new EventSource(`/api/v1/games/${slug}/live`);
    return () => es.close();
  }, [slug]);

  useEffect(() => () => clearTimer(), []);

  return (
    <div className="relative h-full w-full overflow-hidden bg-[#8ec6ef] text-white">
      <div ref={rootRef} className="absolute inset-0" />
      <style>{`
        .oml-ink {
          text-shadow:
            0 2px 0 #1a1208,
            2px 0 0 #1a1208,
            -2px 0 0 #1a1208,
            0 -2px 0 #1a1208,
            2px 2px 0 #1a1208,
            -2px 2px 0 #1a1208,
            2px -2px 0 #1a1208,
            -2px -2px 0 #1a1208;
        }
        .oml-amount {
          animation: oml-pop 180ms ease-out;
        }
        .oml-delta {
          animation: oml-delta 1.15s ease-out forwards;
        }
        @keyframes oml-pop {
          from { transform: scale(1.06); }
          to { transform: scale(1); }
        }
        @keyframes oml-delta {
          0% { opacity: 0; transform: translateY(10px) scale(0.92); }
          14% { opacity: 1; transform: translateY(0) scale(1.06); }
          70% { opacity: 1; transform: translateY(0) scale(1); }
          100% { opacity: 0; transform: translateY(-12px); }
        }
        .oml-panel {
          position: absolute;
          z-index: 20;
          top: 12px;
          right: 12px;
          bottom: 12px;
          width: min(292px, calc(100vw - 24px));
          overflow: auto;
        }
        .oml-readout {
          position: absolute;
          z-index: 10;
          top: 0;
          bottom: 0;
          left: 0;
          right: 312px;
          display: flex;
          align-items: center;
          justify-content: center;
          pointer-events: none;
        }
        @media (max-width: 860px) {
          .oml-panel {
            top: auto;
            left: 8px;
            right: 8px;
            width: auto;
            max-height: 46vh;
          }
          .oml-readout {
            right: 0;
            bottom: auto;
            height: 42vh;
            align-items: flex-end;
            padding-bottom: 8px;
          }
        }
      `}</style>

      <div className="oml-readout">
        <div className="px-4 text-center">
          <p className="oml-ink text-[clamp(1.6rem,3vw,2.6rem)] font-black tracking-[0.16em]">
            GRASS LEFT
          </p>
          <p
            key={grass}
            data-testid="grass-amount"
            className="oml-amount oml-ink mt-1 font-black leading-none tabular-nums text-[#ffe56a]"
            style={{ fontSize: "clamp(4.2rem, 9vw, 7.6rem)" }}
          >
            {formatGrass(grass)}
          </p>
          <div className="mt-1 h-[1.35em]">
            {delta && (
              <p
                key={delta.id}
                data-testid="grass-delta"
                className={`oml-delta oml-ink text-[clamp(1.8rem,4vw,3.2rem)] font-black leading-none tabular-nums ${
                  delta.applied > 0 ? "text-[#39f06a]" : "text-[#ff3b3b]"
                }`}
              >
                {formatDelta(delta.applied)}
              </p>
            )}
          </div>
        </div>
      </div>

      {countdown !== null && (
        <>
          <div className="pointer-events-none absolute inset-0 z-20 bg-[radial-gradient(circle,transparent_28%,rgba(150,0,0,0.38)_100%)]" />
          <div className="pointer-events-none absolute inset-0 z-30 flex items-center justify-center">
            <span
              data-testid="countdown"
              className="oml-ink font-black leading-none text-[#ff2a2a]"
              style={{ fontSize: "clamp(7rem, 18vw, 12rem)" }}
            >
              {countdown}
            </span>
          </div>
        </>
      )}

      <aside className="oml-panel rounded-3xl border border-white/25 bg-black/45 p-3 shadow-[0_12px_40px_rgba(0,0,0,0.28)] backdrop-blur-md">
        <div className="grid grid-cols-1 gap-1.5">
          {ADD_STEPS.map((step) => (
            <button
              key={`add-${step}`}
              type="button"
              data-testid={`add-${step}`}
              disabled={locked}
              onClick={() => changeBy(step)}
              className="h-11 rounded-xl bg-[#1f9d4a] text-sm font-extrabold text-white shadow disabled:opacity-45"
            >
              Add {formatGrass(step)}
            </button>
          ))}
          {REMOVE_STEPS.map((step) => (
            <button
              key={`remove-${step}`}
              type="button"
              data-testid={`remove-${step}`}
              disabled={locked}
              onClick={() => changeBy(-step)}
              className="h-11 rounded-xl bg-[#d23b3b] text-sm font-extrabold text-white shadow disabled:opacity-45"
            >
              Remove {formatGrass(step)}
            </button>
          ))}
        </div>

        <div className="mt-3 rounded-2xl bg-black/30 px-3 py-2">
          <div className="flex items-baseline justify-between gap-2">
            <span className="text-xs font-bold tracking-[0.16em] text-white/80">
              CUSTOM
            </span>
            <span
              data-testid="custom-value"
              className="text-xl font-black tabular-nums text-[#ffe56a]"
            >
              {formatGrass(custom)}
            </span>
          </div>
          <input
            data-testid="custom-slider"
            className="mt-2 h-8 w-full accent-[#39f06a]"
            type="range"
            min={0}
            max={CUSTOM_STOPS.length - 1}
            step={1}
            value={customIndex}
            aria-label="Custom amount"
            aria-valuetext={formatGrass(custom)}
            disabled={locked}
            onChange={(event) => setCustomIndex(Number(event.target.value))}
          />
          <div className="flex justify-between text-[10px] font-bold text-white/70">
            <span>{formatGrass(CUSTOM_STOPS[0])}</span>
            <span>{formatGrass(CUSTOM_STOPS[CUSTOM_STOPS.length - 1]!)}</span>
          </div>
        </div>

        <div className="mt-2 grid grid-cols-2 gap-1.5">
          <button
            type="button"
            data-testid="add-custom"
            disabled={locked}
            onClick={() => changeBy(custom)}
            className="h-11 rounded-xl bg-[#147a38] text-sm font-extrabold disabled:opacity-45"
          >
            Add custom
          </button>
          <button
            type="button"
            data-testid="remove-custom"
            disabled={locked}
            onClick={() => changeBy(-custom)}
            className="h-11 rounded-xl bg-[#a82828] text-sm font-extrabold disabled:opacity-45"
          >
            Remove custom
          </button>
        </div>

        <div className="mt-2 grid grid-cols-1 gap-1.5">
          <button
            type="button"
            data-testid="reset"
            disabled={locked}
            onClick={startCountdown}
            className="h-11 rounded-xl bg-[#9d1824] text-sm font-extrabold disabled:opacity-45"
          >
            Reset
          </button>
          <button
            type="button"
            data-testid="instant-reset"
            onClick={instantReset}
            className="h-11 rounded-xl bg-[#2a2f33] text-sm font-extrabold disabled:opacity-45"
          >
            Instant reset
          </button>
          <button
            type="button"
            data-testid="save"
            onClick={save}
            className="h-11 rounded-xl bg-[#f0c014] text-sm font-extrabold text-[#1a1208] disabled:opacity-45"
          >
            {saved ? "Saved" : "Save"}
          </button>
        </div>
        {saveNote && (
          <p className="mt-2 text-center text-xs font-bold text-[#ffb4b4]">
            {saveNote}
          </p>
        )}
      </aside>
    </div>
  );
}

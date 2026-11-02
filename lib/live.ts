export type LiveActionEvent = {
  type: "action";
  slug: string;
  giftName: string;
  action: string;
  repeatCount: number;
  label?: string;
};

export type LiveStatusEvent = {
  type: "status";
  message: string;
};

export type LiveEvent = LiveActionEvent | LiveStatusEvent;

type Subscriber = {
  userId: string;
  slug: string;
  send: (event: LiveEvent) => void;
};

const subscribers = new Set<Subscriber>();

const fingerprints = new Map<string, number>();
const FINGERPRINT_TTL_MS = 30_000;

export function subscribeLive(
  userId: string,
  slug: string,
  send: (event: LiveEvent) => void,
): () => void {
  const sub: Subscriber = { userId, slug, send };
  subscribers.add(sub);
  return () => {
    subscribers.delete(sub);
  };
}

export function publishAction(
  userId: string,
  slug: string,
  payload: Omit<LiveActionEvent, "type" | "slug">,
) {
  const event: LiveActionEvent = { type: "action", slug, ...payload };
  for (const sub of subscribers) {
    if (sub.userId === userId && sub.slug === slug) sub.send(event);
  }
}

export function fingerprintSeen(key: string): boolean {
  const now = Date.now();
  for (const [k, t] of fingerprints) {
    if (now - t > FINGERPRINT_TTL_MS) fingerprints.delete(k);
  }
  if (fingerprints.has(key)) return true;
  fingerprints.set(key, now);
  return false;
}

/** Test helper — clear in-memory state between tests. */
export function __resetLiveForTests() {
  subscribers.clear();
  fingerprints.clear();
}

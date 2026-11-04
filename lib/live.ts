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

type Waiter = {
  userId: string;
  slug: string;
  push: (event: LiveEvent) => void;
};

const waiters = new Set<Waiter>();
const queues = new Map<string, LiveEvent[]>();
const QUEUE_CAP = 50;

const fingerprints = new Map<string, number>();
const FINGERPRINT_TTL_MS = 30_000;

function queueKey(userId: string, slug: string) {
  return `${userId}\0${slug}`;
}

function drain(key: string): LiveEvent[] {
  const queued = queues.get(key);
  if (!queued?.length) return [];
  queues.delete(key);
  return queued;
}

function enqueue(key: string, event: LiveEvent) {
  const queued = queues.get(key) ?? [];
  queued.push(event);
  queues.set(key, queued.slice(-QUEUE_CAP));
}

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
  const key = queueKey(userId, slug);
  let handed = false;
  for (const waiter of [...waiters]) {
    if (waiter.userId === userId && waiter.slug === slug) {
      handed = true;
      waiter.push(event);
    }
  }
  if (!handed) enqueue(key, event);
}

/** Next queued actions, or wait until one arrives or the timeout elapses. */
export function takeLive(
  userId: string,
  slug: string,
  timeoutMs: number,
  signal?: AbortSignal,
): Promise<LiveEvent[]> {
  const key = queueKey(userId, slug);
  const queued = drain(key);
  if (queued.length) return Promise.resolve(queued);
  if (signal?.aborted) return Promise.resolve([]);

  return new Promise((resolve) => {
    let settled = false;
    const pending: {
      waiter?: Waiter;
      timer?: ReturnType<typeof setTimeout>;
    } = {};
    const finish = (events: LiveEvent[]) => {
      if (settled) return;
      settled = true;
      clearTimeout(pending.timer);
      signal?.removeEventListener("abort", onAbort);
      if (pending.waiter) waiters.delete(pending.waiter);
      resolve(events);
    };
    const onAbort = () => finish([]);
    const waiter: Waiter = {
      userId,
      slug,
      push: (event) => finish([event, ...drain(key)]),
    };
    pending.waiter = waiter;
    waiters.add(waiter);
    pending.timer = setTimeout(() => finish(drain(key)), timeoutMs);
    signal?.addEventListener("abort", onAbort);
  });
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
  waiters.clear();
  queues.clear();
  fingerprints.clear();
}

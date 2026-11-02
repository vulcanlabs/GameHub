import { redirect } from "next/navigation";
import { auth, isGoogleAuthConfigured, signIn } from "@/lib/auth";

export default async function LoginPage({
  searchParams,
}: {
  searchParams: Promise<{ callbackUrl?: string; error?: string }>;
}) {
  const session = await auth();
  const params = await searchParams;
  if (session?.user) {
    redirect(params.callbackUrl || "/");
  }

  const configured = isGoogleAuthConfigured();

  return (
    <div className="flex min-h-full items-center justify-center px-4 py-10">
      <div className="w-full max-w-[480px] rounded-[36px] bg-[var(--card)] p-7 text-[var(--card-ink)] shadow-[0_18px_40px_rgba(22,48,52,0.18)]">
        <p className="text-xs font-bold tracking-[0.22em] text-[var(--card-mute)]">
          GAME HUB
        </p>
        <h1 className="mt-3 text-5xl leading-none font-extrabold tracking-tight">
          Sign in
        </h1>
        <p className="mt-4 text-lg text-[var(--card-mute)]">
          Google is the only login. Each account gets its own TikFinity hook
          and gift bindings.
        </p>

        {!configured ? (
          <div className="mt-6 rounded-[28px] bg-[#fde8ea] p-5 text-base">
            <b className="text-lg text-[var(--bad)]">
              Google OAuth is not configured
            </b>
            <p className="mt-2 text-[var(--card-mute)]">
              Set <code>AUTH_GOOGLE_ID</code> and <code>AUTH_GOOGLE_SECRET</code>{" "}
              in <code>.env</code>. Create an OAuth client in Google Cloud with
              redirect URI{" "}
              <code className="break-all font-bold text-[var(--card-ink)]">
                http://localhost:3000/api/auth/callback/google
              </code>
              . See the README.
            </p>
          </div>
        ) : (
          <form
            className="mt-8"
            action={async () => {
              "use server";
              await signIn("google", {
                redirectTo: params.callbackUrl || "/",
              });
            }}
          >
            <button
              type="submit"
              className="h-16 w-full rounded-full bg-[var(--card-ink)] text-xl font-bold text-[var(--ink)]"
            >
              Continue with Google
            </button>
          </form>
        )}

        {params.error && (
          <p className="mt-4 text-base font-semibold text-[var(--bad)]">
            Sign-in error: {params.error}
          </p>
        )}
      </div>
    </div>
  );
}

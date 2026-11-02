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
    <div className="flex min-h-full items-center justify-center p-8">
      <div className="w-full max-w-md rounded-2xl border border-[var(--line)] bg-[var(--panel)] p-8">
        <h1 className="text-2xl font-bold">Sign in to Game Hub</h1>
        <p className="mt-2 text-[var(--mute)]">
          Google is the only login. Each account gets its own TikFinity hook URL
          and gift bindings.
        </p>

        {!configured ? (
          <div className="mt-6 rounded-xl border border-[var(--bad)]/40 bg-[#2a1515] p-4 text-sm">
            <b className="text-[var(--bad)]">Google OAuth is not configured</b>
            <p className="mt-2 text-[var(--mute)]">
              Set <code>AUTH_GOOGLE_ID</code> and <code>AUTH_GOOGLE_SECRET</code>{" "}
              in <code>.env</code>. Create an OAuth client in Google Cloud with
              redirect URI{" "}
              <code className="break-all text-[var(--acc)]">
                http://localhost:3000/api/auth/callback/google
              </code>
              . See the README.
            </p>
          </div>
        ) : (
          <form
            className="mt-6"
            action={async () => {
              "use server";
              await signIn("google", {
                redirectTo: params.callbackUrl || "/",
              });
            }}
          >
            <button
              type="submit"
              className="w-full rounded-full bg-white px-6 py-3 font-bold text-[#111]"
            >
              Continue with Google
            </button>
          </form>
        )}

        {params.error && (
          <p className="mt-4 text-sm text-[var(--bad)]">
            Sign-in error: {params.error}
          </p>
        )}
      </div>
    </div>
  );
}

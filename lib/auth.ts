import NextAuth from "next-auth";
import Google from "next-auth/providers/google";
import { PrismaAdapter } from "@auth/prisma-adapter";
import { prisma } from "./prisma";
import { generateHookToken } from "./hooks";
import { isAdminEmail, roleForEmail } from "./roles";

const googleConfigured =
  Boolean(process.env.AUTH_GOOGLE_ID) && Boolean(process.env.AUTH_GOOGLE_SECRET);

export const { handlers, auth, signIn, signOut } = NextAuth({
  adapter: PrismaAdapter(prisma),
  providers: googleConfigured
    ? [
        Google({
          clientId: process.env.AUTH_GOOGLE_ID!,
          clientSecret: process.env.AUTH_GOOGLE_SECRET!,
        }),
      ]
    : [],
  session: { strategy: "database" },
  pages: {
    signIn: "/login",
  },
  callbacks: {
    async session({ session, user }) {
      if (session.user) {
        session.user.id = user.id;
        const dbUser = await prisma.user.findUnique({
          where: { id: user.id },
          select: { role: true, active: true, email: true },
        });
        const role =
          dbUser?.role === "admin" || isAdminEmail(dbUser?.email ?? user.email)
            ? "admin"
            : "user";
        session.user.role = role;
        session.user.active = role === "admin" ? true : Boolean(dbUser?.active);
      }
      return session;
    },
  },
  events: {
    async createUser({ user }) {
      if (!user.id) return;
      const role = roleForEmail(user.email);
      await prisma.user.update({
        where: { id: user.id },
        data: {
          hookToken: generateHookToken(),
          role,
          active: role === "admin",
        },
      });
    },
    async signIn({ user }) {
      if (!user.id || !user.email) return;
      if (!isAdminEmail(user.email)) return;
      await prisma.user.update({
        where: { id: user.id },
        data: { role: "admin", active: true },
      });
    },
  },
  trustHost: true,
});

export function isGoogleAuthConfigured() {
  return googleConfigured;
}

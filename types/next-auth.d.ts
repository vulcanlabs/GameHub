import { DefaultSession } from "next-auth";

declare module "next-auth" {
  interface Session {
    user: {
      id: string;
      role: "admin" | "user";
      active: boolean;
      accessUntil: string | null;
    } & DefaultSession["user"];
  }

  interface User {
    role?: "admin" | "user";
    active?: boolean;
    accessUntil?: string | null;
  }
}

import { NextResponse } from "next/server";

export type ApiErrorBody = { code: string; message: string };

export function apiError(status: number, code: string, message: string) {
  return NextResponse.json({ code, message } satisfies ApiErrorBody, { status });
}

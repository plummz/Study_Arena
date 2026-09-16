import {
  API_CONFIGURED,
  API_UNAVAILABLE_MESSAGE,
  API_URL,
} from "./config.js";
import { uuid } from "./vault.js";
export class ApiError extends Error {
  constructor(message, code, status) {
    super(message);
    Object.assign(this, { code, status });
  }
}
export class Client {
  constructor(vault = null) {
    this.vault = vault;
    this.token = vault?.data.token || "";
    this.syncing = false;
    this.backoff = 1000;
  }
  async request(
    path,
    { method = "GET", body, key, cache = true, timeout = 10000 } = {},
  ) {
    if (method === "GET" && cache && !navigator.onLine && this.vault?.data.cache[path]) return { ...this.vault.data.cache[path].data, offline: true };
    if (!API_CONFIGURED && path.startsWith("/api/"))
      throw new ApiError(
        API_UNAVAILABLE_MESSAGE,
        "BACKEND_UNAVAILABLE",
        503,
      );
    const controller = new AbortController(),
      timer = setTimeout(() => controller.abort(), timeout);
    try {
      const response = await fetch(API_URL + path, {
        method,
        signal: controller.signal,
        headers: {
          ...(body ? { "Content-Type": "application/json" } : {}),
          ...(this.token ? { Authorization: `Bearer ${this.token}` } : {}),
          ...(key ? { "Idempotency-Key": key } : {}),
        },
        ...(body ? { body: JSON.stringify(body) } : {}),
      });
      const responseText = await response.text();
      let data;
      try {
        data = JSON.parse(responseText);
      } catch {
        const contentType = response.headers.get("content-type") || "";
        const looksLikeHtml =
          contentType.includes("text/html") ||
          responseText.trimStart().startsWith("<");
        throw new ApiError(
          looksLikeHtml
            ? API_UNAVAILABLE_MESSAGE
            : "The Study Arena server returned an unreadable response. Please try again.",
          looksLikeHtml ? "BACKEND_UNAVAILABLE" : "INVALID_RESPONSE",
          503,
        );
      }
      if (!response.ok)
        throw new ApiError(
          data.error?.message || "Request failed.",
          data.error?.code || "HTTP_ERROR",
          response.status,
        );
      if (
        method === "GET" &&
        cache &&
        this.vault &&
        !path.startsWith("/api/admin") &&
        !path.includes("/export")
      ) {
        this.vault.data.cache[path] = { data, at: Date.now() };
        await this.vault.save();
      }
      return data;
    } catch (error) {
      if (
        !(error instanceof ApiError) &&
        method === "GET" &&
        cache &&
        this.vault?.data.cache[path]
      )
        return { ...this.vault.data.cache[path].data, offline: true };
      throw error;
    } finally {
      clearTimeout(timer);
    }
  }
  async mutate(
    path,
    body = {},
    { method = "POST", queue = false, key = uuid(), timeout = 10000 } = {},
  ) {
    if (!queue) return this.request(path, { method, body, key, cache: false, timeout });
    if (!this.vault) throw new Error("Sign in to save study activity.");
    // Persist BEFORE networking: a killed app or uncertain timeout cannot lose a committed operation.
    this.vault.data.pending.push({
      id: key,
      path,
      method,
      body,
      created: Date.now(),
      error: null,
    });
    await this.vault.save();
    await this.sync();
    return {
      pending: this.vault.data.pending.some((op) => op.id === key),
      result: this.lastResult?.key === key ? this.lastResult.data : null,
    };
  }
  async sync() {
    if (this.syncing || !this.vault || !navigator.onLine || !this.token) return;
    this.syncing = true;
    try {
      const batch = this.vault.data.pending.slice(0, 20);
      for (const op of batch) {
        if (op.error) continue;
        try {
          const data = await this.request(op.path, {
            method: op.method,
            body: op.body,
            key: op.id,
            cache: false,
          });
          this.lastResult = { key: op.id, data };
          this.vault.data.pending = this.vault.data.pending.filter(
            (x) => x.id !== op.id,
          );
          if (data.wallet) this.vault.data.wallet = data.wallet;
          await this.vault.save();
          this.backoff = 1000;
        } catch (error) {
          if (
            error instanceof ApiError &&
            error.status >= 400 &&
            error.status < 500 &&
            ![401, 429].includes(error.status)
          ) {
            op.error = `${error.code}: ${error.message}`;
            await this.vault.save();
            continue;
          }
          this.backoff = Math.min(this.backoff * 2, 60000);
          break;
        }
      }
    } finally {
      this.syncing = false;
    }
  }
}

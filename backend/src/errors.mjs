export class AppError extends Error {
  constructor(code, status = 502, retryAfter = 30) {
    super(code); this.code = code; this.status = status; this.retryAfter = retryAfter;
  }
}

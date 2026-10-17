// In-memory ring buffer of the private-interface calls the app made, newest
// first. Nothing is persisted: this exists so a user can see which request
// failed and with what status, instead of only getting a toast.
export class RequestLogEntry {
  time: number = 0;
  operation: string = '';
  status: number = 0;
  ok: boolean = false;
  note: string = '';

  constructor(time: number, operation: string, status: number, ok: boolean, note: string) {
    this.time = time;
    this.operation = operation;
    this.status = status;
    this.ok = ok;
    this.note = note;
  }
}

class RequestLog {
  private static readonly MAX_ENTRIES: number = 60;
  private entries: RequestLogEntry[] = [];

  record(operation: string, status: number, ok: boolean, note: string): void {
    this.entries.unshift(new RequestLogEntry(Date.now(), operation, status, ok, note));
    while (this.entries.length > RequestLog.MAX_ENTRIES) {
      this.entries.pop();
    }
  }

  snapshot(): RequestLogEntry[] {
    const copy: RequestLogEntry[] = [];
    for (let i: number = 0; i < this.entries.length; i++) {
      copy.push(this.entries[i]);
    }
    return copy;
  }

  clear(): void {
    this.entries = [];
  }
}

export const requestLog: RequestLog = new RequestLog();

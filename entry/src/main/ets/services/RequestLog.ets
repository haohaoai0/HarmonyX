// In-memory ring buffer of the private-interface calls the app made, newest
// first. Full notes stay in memory. The optional diagnostic bridge persists
// only operation/status metadata, so a crash report can retain recent activity.
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
  private diagnosticRecorder: ((operation: string, status: number, ok: boolean) => void) | undefined = undefined;

  setDiagnosticRecorder(recorder: (operation: string, status: number, ok: boolean) => void): void {
    this.diagnosticRecorder = recorder;
  }

  record(operation: string, status: number, ok: boolean, note: string): void {
    if (this.diagnosticRecorder) { this.diagnosticRecorder(operation, status, ok); }
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

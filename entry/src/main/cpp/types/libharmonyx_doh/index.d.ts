export interface NativeDohResponse {
  metadata: string;
  body: ArrayBuffer;
}
export const request: (id: number, metadata: string, body: ArrayBuffer,
  onEvent: (kind: number, metadata: string, data: ArrayBuffer) => void) => Promise<NativeDohResponse>;
export const cancel: (id: number) => void;

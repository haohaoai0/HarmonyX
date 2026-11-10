import { bundleManager, common } from '@kit.AbilityKit';
import { deviceInfo } from '@kit.BasicServicesKit';
import { fileIo, picker } from '@kit.CoreFileKit';
import { hiAppEvent, hilog } from '@kit.PerformanceAnalysisKit';
import { requestLog } from './RequestLog';

export const STORAGE_KEY_CRASH_DIAGNOSTICS: string = 'harmonyx.crash_diagnostics_revision';
const MAX_REPORTS: number = 5;
const MAX_ARCHIVE_BYTES: number = 4 * 1024 * 1024;
const MAX_LOG_BYTES: number = 192 * 1024;
const MAX_REPORT_CHARS: number = 256 * 1024;
const DEVELOPER_URL: string = 'https://github.com/haohaoai0/HarmonyX/issues/new';

interface CrashException {
  name?: string;
  message?: string;
  stack?: string;
}

// Read only the documented system fields; never serialize the entire params object.
interface CrashParams {
  time?: number;
  uuid?: string;
  crash_type?: string;
  bundle_name?: string;
  bundle_version?: string;
  exception?: CrashException;
  hilog?: string[];
  external_log?: string[];
}

export class CrashReport {
  id: string = '';
  time: number = 0;
  type: string = '';
  summary: string = '';
  text: string = '';
  pending: boolean = true;
}

class CrashArchive {
  reports: CrashReport[] = [];
}

class DiagnosticJournal {
  lines: string[] = [];
}

// Apply to disk, preview and export, including system-provided stacks and HiLog.
export function redactDiagnostic(value: string): string {
  return value
    .replace(/\b(Bearer|Basic)\s+[A-Za-z0-9+/_.=:-]+/gi, '$1 [REDACTED]')
    .replace(/((?:authorization|cookie|set-cookie)\s*[=:]\s*)[^\r\n]+/gi, '$1[REDACTED]')
    .replace(/((?:["']?)(?:auth_token|ct0|access_token|refresh_token|oauth_token(?:_secret)?|password|passwd|client_secret|secret|token)(?:["']?)\s*[=:]\s*)(?:"[^"\r\n]*"|'[^'\r\n]*'|[^\s,;&}\r\n]+)/gi, '$1[REDACTED]')
    .replace(/\beyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\b/g, '[REDACTED]')
    .replace(/https?:\/\/[^\s<>"']+/gi, (url: string): string => {
      const query: number = url.indexOf('?');
      const hash: number = url.indexOf('#');
      const end: number = query >= 0 && hash >= 0 ? Math.min(query, hash) : Math.max(query, hash);
      return end >= 0 ? url.substring(0, end) + '?[REDACTED]' : url;
    });
}

export class CrashDiagnostics {
  private directory: string = '';
  private reports: CrashReport[] = [];
  private journal: string[] = [];
  private previousJournal: string[] = [];
  private sessionStarted: number = 0;
  private flushTimer: number = -1;
  private watching: boolean = false;
  private revision: number = 0;
  private promptClaimed: boolean = false;
  private exporting: boolean = false;
  private metadata: string = '';

  initialize(context: common.UIAbilityContext): void {
    if (this.directory.length > 0) { return; }
    this.directory = context.filesDir + '/diagnostics';
    this.sessionStarted = Date.now();
    try {
      if (!fileIo.accessSync(this.directory)) { fileIo.mkdirSync(this.directory); }
      const archive: CrashArchive = JSON.parse(this.readBounded(this.directory + '/crashes.json', MAX_ARCHIVE_BYTES)) as CrashArchive;
      if (Array.isArray(archive.reports)) {
        this.reports = archive.reports.filter((report: CrashReport): boolean =>
          typeof report.id === 'string' && typeof report.text === 'string' &&
          typeof report.time === 'number').slice(0, MAX_REPORTS);
      }
    } catch (error) { this.warn('Unable to restore crash archive'); }
    try {
      const saved: DiagnosticJournal = JSON.parse(this.readBounded(this.directory + '/session.json', 64 * 1024)) as DiagnosticJournal;
      if (Array.isArray(saved.lines)) {
        this.previousJournal = saved.lines.filter((line: string): boolean => typeof line === 'string').slice(-80);
      }
    } catch (error) { /* A first launch has no previous session. */ }
    this.metadata = this.deviceMetadata();
    this.record('application.create');
    this.flush();
    requestLog.setDiagnosticRecorder((operation: string, status: number, ok: boolean): void => {
      // Request payloads, response bodies, URLs and account identifiers stay out of the journal.
      this.record('request ' + operation.replace(/[^A-Za-z0-9_. -]/g, '_').substring(0, 100) +
        ' status=' + status.toString() + ' ok=' + ok.toString());
      if (!ok) { this.flush(); }
    });
    this.publish();
    this.startWatcher();
  }

  private startWatcher(): void {
    if (this.watching) { return; }
    try {
      hiAppEvent.addWatcher({
        name: 'harmonyxCrashDiagnostics',
        appEventFilters: [{ domain: hiAppEvent.domain.OS, names: [hiAppEvent.event.APP_CRASH] }],
        onReceive: (domain: string, groups: hiAppEvent.AppEventGroup[]): void => {
          if (domain !== hiAppEvent.domain.OS) { return; }
          for (const group of groups) {
            for (const event of group.appEventInfos) {
              if (event.name !== hiAppEvent.event.APP_CRASH) { continue; }
              try { this.ingest(event); }
              catch (error) { this.warn('Unable to save crash event'); }
            }
          }
        }
      });
      this.watching = true;
    } catch (error) { this.warn('Unable to subscribe to crash events'); }
  }

  private deviceMetadata(): string {
    let version: string = '';
    try {
      const info: bundleManager.BundleInfo = bundleManager.getBundleInfoForSelfSync(
        bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION);
      version = 'Bundle: ' + info.name + '\nApp version: ' + info.versionName + ' (' + info.versionCode + ')\n';
    } catch (error) { /* Device and system version remain available. */ }
    return version + 'Device: ' + deviceInfo.manufacture + ' ' + deviceInfo.productModel +
      '\nOS: ' + deviceInfo.osFullName + '\nAPI: ' + deviceInfo.sdkApiVersion + '\n';
  }

  private readBounded(path: string, limit: number): string {
    if (!fileIo.accessSync(path)) { return ''; }
    const size: number = fileIo.statSync(path).size;
    if (size <= 0) { return ''; }
    return fileIo.readTextSync(path, { length: Math.min(size, limit) });
  }

  private writeAtomic(name: string, content: string): void {
    const path: string = this.directory + '/' + name;
    const file: fileIo.File = fileIo.openSync(path + '.tmp',
      fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
    try {
      fileIo.writeSync(file.fd, content);
      fileIo.fsyncSync(file.fd);
    } finally { fileIo.closeSync(file.fd); }
    fileIo.renameSync(path + '.tmp', path);
  }

  record(message: string): void {
    if (this.directory.length === 0) { return; }
    this.journal.push(new Date().toISOString() + ' ' + redactDiagnostic(message).substring(0, 512));
    this.journal = this.journal.slice(-80);
    if (this.flushTimer >= 0) { return; }
    this.flushTimer = setTimeout((): void => { this.flush(); }, 1000);
  }

  flush(): void {
    if (this.flushTimer >= 0) { clearTimeout(this.flushTimer); this.flushTimer = -1; }
    if (this.directory.length === 0) { return; }
    try {
      const journal: DiagnosticJournal = new DiagnosticJournal();
      journal.lines = this.journal;
      this.writeAtomic('session.json', JSON.stringify(journal));
    } catch (error) { this.warn('Unable to save diagnostic journal'); }
  }

  private ingest(event: hiAppEvent.AppEventInfo): void {
    const params: CrashParams = event.params as CrashParams;
    const report: CrashReport = new CrashReport();
    report.time = typeof params.time === 'number' && Number.isFinite(params.time) && params.time > 0 ? params.time : Date.now();
    report.type = typeof params.crash_type === 'string' ? params.crash_type : 'APP_CRASH';
    report.id = typeof params.uuid === 'string' && params.uuid.length > 0 ? params.uuid :
      report.type + '-' + report.time.toString();
    if (this.reports.some((saved: CrashReport): boolean => saved.id === report.id)) { return; }
    const exception: CrashException | undefined = params.exception;
    report.summary = redactDiagnostic(exception ? String(exception.name ?? report.type) + ': ' +
      String(exception.message ?? '') : report.type).substring(0, 1000);
    const contextLines: string[] = report.time < this.sessionStarted ? this.previousJournal : this.journal;
    let text: string = 'Crash time: ' + new Date(report.time).toISOString() + '\nType: ' + report.type +
      '\nCrash ID: ' + report.id + '\nCrash bundle: ' + String(params.bundle_name ?? '') +
      '\nCrash version: ' + String(params.bundle_version ?? '') + '\n' + this.metadata +
      '\nException\n' + report.summary + '\n' + String(exception?.stack ?? '') +
      '\n\nRecent application activity\n' + contextLines.join('\n');
    if (Array.isArray(params.external_log)) {
      // Read only OS-produced HiAppEvent crash logs from the application sandbox.
      for (const path of params.external_log.slice(0, 1)) {
        if (typeof path !== 'string' || !path.startsWith('/data/storage/el2/log/hiappevent/') ||
          path.indexOf('..') >= 0) { continue; }
        try { text += '\n\nSystem crash log\n' + this.readBounded(path, MAX_LOG_BYTES); }
        catch (error) { text += '\nSystem crash log unavailable; event stack retained.\n'; }
      }
    }
    if (Array.isArray(params.hilog)) {
      text += '\n\nRecent system log\n' + params.hilog.slice(-80)
        .filter((line: string): boolean => typeof line === 'string')
        .map((line: string): string => line.substring(0, 2048)).join('\n');
    }
    report.text = redactDiagnostic(text).substring(0, MAX_REPORT_CHARS);
    this.reports.push(report);
    this.reports.sort((left: CrashReport, right: CrashReport): number => right.time - left.time);
    this.reports = this.reports.slice(0, MAX_REPORTS);
    this.saveArchive();
    this.publish();
  }

  private saveArchive(): void {
    try {
      const archive: CrashArchive = new CrashArchive();
      archive.reports = this.reports;
      this.writeAtomic('crashes.json', JSON.stringify(archive));
    } catch (error) { this.warn('Unable to persist crash archive'); }
  }

  private publish(): void {
    this.revision++;
    AppStorage.setOrCreate<number>(STORAGE_KEY_CRASH_DIAGNOSTICS, this.revision);
  }

  snapshot(): CrashReport[] { return this.reports.slice(); }

  pendingReport(): CrashReport | undefined {
    return this.reports.find((report: CrashReport): boolean => report.pending);
  }

  claimPrompt(id: string): boolean {
    if (this.promptClaimed || !this.reports.some((report: CrashReport): boolean => report.id === id && report.pending)) { return false; }
    this.promptClaimed = true;
    return true;
  }

  acknowledge(id: string): void {
    const report: CrashReport | undefined = this.reports.find((saved: CrashReport): boolean => saved.id === id);
    if (!report) { return; }
    report.pending = false;
    this.saveArchive();
    this.publish();
  }

  async exportLogs(context: common.UIAbilityContext): Promise<boolean> {
    if (this.exporting) { return false; }
    this.exporting = true;
    try { return await this.writeExport(context); }
    finally { this.exporting = false; }
  }

  private async writeExport(context: common.UIAbilityContext): Promise<boolean> {
    this.flush();
    const reports: CrashReport[] = this.snapshot();
    const sections: string[] = ['Application diagnostics\nExported: ' + new Date().toISOString(), this.metadata];
    for (const report of reports) { sections.push(report.text); }
    sections.push('Current session\n' + this.journal.join('\n'));
    const content: string = redactDiagnostic(sections.join('\n\n====================\n\n'));
    const options: picker.DocumentSaveOptions = new picker.DocumentSaveOptions();
    options.newFileNames = ['app-diagnostics-' + Date.now().toString() + '.txt'];
    options.fileSuffixChoices = ['Text|.txt'];
    let uris: string[] = [];
    try { uris = await new picker.DocumentViewPicker(context).save(options); }
    catch (error) {
      if (String((error as Error).message ?? '').toLowerCase().indexOf('cancel') >= 0) { return false; }
      throw error as Error;
    }
    if (uris.length === 0) { return false; }
    const file: fileIo.File = fileIo.openSync(uris[0], fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC);
    try { fileIo.writeSync(file.fd, content); fileIo.fsyncSync(file.fd); }
    finally { fileIo.closeSync(file.fd); }
    for (const report of reports) { this.acknowledge(report.id); }
    return true;
  }

  async contactDeveloper(context: common.UIAbilityContext): Promise<void> {
    await context.startAbility({ action: 'ohos.want.action.viewData',
      entities: ['entity.system.browsable'], uri: DEVELOPER_URL });
  }

  private warn(message: string): void { hilog.warn(0xFF00, 'CrashDiagnostics', '%{public}s', message); }
}

export const crashDiagnostics: CrashDiagnostics = new CrashDiagnostics();

import fs from '@ohos.file.fs';
import { common } from '@kit.AbilityKit';
import { formProvider } from '@kit.FormKit';
import hilog from '@ohos.hilog';
import { ArticleCardItem } from '../models/ArticleCardItem';
import { ArticleCardStore } from './ArticleCardStore';
import { ArticleCardImages, ArticleCardImageBinding } from './ArticleCardImages';

const DOMAIN = 0xFF00;
const TAG = 'HarmonyX-ArticleCardPublisher';
const FILE_NAME = 'article-card-forms.json';
const DEFAULT_DIMENSION: string = '2*4';

class FormRecord {
  id: string = '';
  dimension: string = DEFAULT_DIMENSION;
  cellWidth: number = 0;
  cellHeight: number = 0;
  geometryVersion: number = 0;
}

class FormRecordPayload {
  records: FormRecord[] = [];
}

class FormDimensions {
  columns: number = 4;
  rows: number = 2;
}

// The form extension owns registration; the app process only reads the list
// when it has fresh timeline data to push.
export class ArticleCardPublisher {
  private static path(context: common.Context): string {
    return context.filesDir + '/' + FILE_NAME;
  }

  private static read(context: common.Context): FormRecordPayload {
    try {
      const path: string = ArticleCardPublisher.path(context);
      if (!fs.accessSync(path)) {
        return new FormRecordPayload();
      }
      const parsed: FormRecordPayload = JSON.parse(fs.readTextSync(path)) as FormRecordPayload;
      const payload: FormRecordPayload = new FormRecordPayload();
      const records: FormRecord[] = parsed.records ?? [];
      for (let i: number = 0; i < records.length; i++) {
        const record: FormRecord = records[i];
        if (record.id.length === 0 || ArticleCardPublisher.indexOf(payload.records, record.id) >= 0) {
          continue;
        }
        payload.records.push(ArticleCardPublisher.copy(record));
      }
      return payload;
    } catch (error) {
      return new FormRecordPayload();
    }
  }

  private static copy(record: FormRecord): FormRecord {
    const out: FormRecord = new FormRecord();
    out.id = record.id;
    out.dimension = record.dimension.length > 0 ? record.dimension : DEFAULT_DIMENSION;
    out.cellWidth = record.cellWidth ?? 0;
    out.cellHeight = record.cellHeight ?? 0;
    out.geometryVersion = record.geometryVersion ?? 0;
    return out;
  }

  private static indexOf(records: FormRecord[], formId: string): number {
    for (let i: number = 0; i < records.length; i++) {
      if (records[i].id === formId) {
        return i;
      }
    }
    return -1;
  }

  private static write(context: common.Context, payload: FormRecordPayload): void {
    let file: fs.File | undefined = undefined;
    const path: string = ArticleCardPublisher.path(context);
    const temporary: string = path + '.tmp';
    try {
      file = fs.openSync(temporary, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
      fs.writeSync(file.fd, JSON.stringify(payload));
      fs.closeSync(file);
      file = undefined;
      fs.renameSync(temporary, path);
    } catch (error) {
      if (file !== undefined) {
        try {
          fs.closeSync(file);
        } catch (closeError) {
        }
      }
    }
  }

  private static dimensionParts(dimension: string): FormDimensions {
    const parts: string[] = dimension.split('*');
    const out: FormDimensions = new FormDimensions();
    if (parts.length !== 2) {
      return out;
    }
    // Form dimensions are rows * columns, so 2*4 is the wide card.
    const rows: number = Number(parts[0]);
    const columns: number = Number(parts[1]);
    if (Number.isFinite(columns) && columns > 0) {
      out.columns = columns;
    }
    if (Number.isFinite(rows) && rows > 0) {
      out.rows = rows;
    }
    return out;
  }

  private static dimensionFromGeometry(record: FormRecord, width: number, height: number): string {
    if (width <= 0 || height <= 0) {
      return record.dimension;
    }
    let columns: number = 4;
    let rows: number = 2;
    if (record.cellWidth > 0) {
      columns = Math.round(width / record.cellWidth);
    }
    if (record.cellHeight > 0) {
      rows = Math.round(height / record.cellHeight);
    }
    columns = columns < 2 ? 2 : columns > 4 ? 4 : columns;
    rows = rows < 2 ? 2 : rows > 4 ? 4 : rows;
    return rows.toString() + '*' + columns.toString();
  }

  static register(context: common.Context, formId: string, dimension: string): void {
    if (formId.length === 0) {
      return;
    }
    const payload: FormRecordPayload = ArticleCardPublisher.read(context);
    const at: number = ArticleCardPublisher.indexOf(payload.records, formId);
    if (at >= 0) {
      if (dimension.length > 0) {
        if (payload.records[at].dimension !== dimension) {
          payload.records[at].cellWidth = 0;
          payload.records[at].cellHeight = 0;
        }
        payload.records[at].dimension = dimension;
      }
    } else {
      const record: FormRecord = new FormRecord();
      record.id = formId;
      record.dimension = dimension.length > 0 ? dimension : DEFAULT_DIMENSION;
      payload.records.push(record);
    }
    ArticleCardPublisher.write(context, payload);
  }

  static unregister(context: common.Context, formId: string): void {
    const payload: FormRecordPayload = ArticleCardPublisher.read(context);
    const at: number = ArticleCardPublisher.indexOf(payload.records, formId);
    if (at < 0) {
      return;
    }
    payload.records.splice(at, 1);
    ArticleCardPublisher.write(context, payload);
  }

  // Called from the form extension after the launcher reports the live
  // rectangle. The first rect calibrates one grid cell, so later resizes can
  // be mapped back to 2*2, 2*4 or 4*4 without onAddForm being called again.
  static updateGeometry(context: common.Context, formId: string, width: number, height: number,
    dimensionHint: string = ''): string {
    const payload: FormRecordPayload = ArticleCardPublisher.read(context);
    let at: number = ArticleCardPublisher.indexOf(payload.records, formId);
    if (at < 0) {
      const record: FormRecord = new FormRecord();
      record.id = formId;
      record.dimension = dimensionHint.length > 0 ? dimensionHint : DEFAULT_DIMENSION;
      payload.records.push(record);
      at = payload.records.length - 1;
    }
    const record: FormRecord = payload.records[at];
    if (dimensionHint.length > 0) {
      record.dimension = dimensionHint;
      record.cellWidth = 0;
      record.cellHeight = 0;
    }
    if (record.geometryVersion !== 2) {
      record.cellWidth = 0;
      record.cellHeight = 0;
      record.geometryVersion = 2;
    }
    if (width > 0 && height > 0 && record.cellWidth <= 0) {
      const parts: FormDimensions = ArticleCardPublisher.dimensionParts(record.dimension);
      record.cellWidth = width / parts.columns;
      record.cellHeight = height / parts.rows;
    }
    record.dimension = ArticleCardPublisher.dimensionFromGeometry(record, width, height);
    ArticleCardPublisher.write(context, payload);
    return record.dimension;
  }

  static publish(context: common.Context): void {
    const payload: FormRecordPayload = ArticleCardPublisher.read(context);
    if (payload.records.length === 0) {
      return;
    }
    ArticleCardPublisher.publishCached(context);
    ArticleCardImages.warm(context, ArticleCardStore.loadForWidget(context)).then((changed: boolean): void => {
      if (changed) {
        // Read the current account/source again after asynchronous image work.
        ArticleCardPublisher.publishCached(context);
      }
    }).catch((): void => { });
  }

  private static publishCached(context: common.Context): void {
    const payload: FormRecordPayload = ArticleCardPublisher.read(context);
    const items: ArticleCardItem[] = ArticleCardStore.loadForWidget(context);
    const source: string = ArticleCardStore.selectedSource(context);
    for (let i: number = 0; i < payload.records.length; i++) {
      const record: FormRecord = payload.records[i];
      const images: ArticleCardImageBinding = ArticleCardImages.bind(context, items, record.dimension, source);
      formProvider.updateForm(record.id, images.bindingData()).catch((error: Error): void => {
        hilog.debug(DOMAIN, TAG, 'article card update failed: %{public}s', error.message);
      }).finally((): void => images.close());
    }
  }
}

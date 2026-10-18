import { common } from '@kit.AbilityKit';
import { relationalStore } from '@kit.ArkData';
import { CardDraft, CardRecord, CardState } from '../models/CardRecord';

export class ImportResult {
  added: number = 0;
  existing: number = 0;
  duplicateLines: number = 0;
  invalidLines: number = 0;

  constructor(added: number, existing: number, duplicateLines: number, invalidLines: number) {
    this.added = added;
    this.existing = existing;
    this.duplicateLines = duplicateLines;
    this.invalidLines = invalidLines;
  }
}

export class CardRepository {
  private static readonly TABLE: string = 'cards';
  private store: relationalStore.RdbStore | null = null;
  private ready: Promise<void> | null = null;

  async initialize(context: common.Context): Promise<void> {
    if (this.ready !== null) {
      await this.ready;
      return;
    }
    this.ready = this.open(context);
    await this.ready;
  }

  private async open(context: common.Context): Promise<void> {
    const config: relationalStore.StoreConfig = {
      name: 'card_vault.db',
      securityLevel: relationalStore.SecurityLevel.S2
    };
    this.store = await relationalStore.getRdbStore(context, config);
    const createSql: string = 'CREATE TABLE IF NOT EXISTS cards (' +
      'id INTEGER PRIMARY KEY AUTOINCREMENT, ' +
      'card_key TEXT NOT NULL UNIQUE, ' +
      'recipient TEXT NOT NULL DEFAULT \'\', ' +
      'donation REAL NOT NULL DEFAULT 0, ' +
      'state TEXT NOT NULL DEFAULT \'unused\', ' +
      'note TEXT NOT NULL DEFAULT \'\', ' +
      'created_at INTEGER NOT NULL, ' +
      'updated_at INTEGER NOT NULL)';
    await this.requireStore().executeSql(createSql);
    await this.requireStore().executeSql('CREATE INDEX IF NOT EXISTS idx_cards_recipient ON cards(recipient)');
    await this.requireStore().executeSql('CREATE INDEX IF NOT EXISTS idx_cards_state ON cards(state)');
    await this.requireStore().executeSql(
      'CREATE INDEX IF NOT EXISTS idx_cards_updated ON cards(updated_at DESC)');
  }

  async listCards(context: common.Context): Promise<CardRecord[]> {
    await this.initialize(context);
    const resultSet: relationalStore.ResultSet = await this.requireStore().querySql(
      'SELECT id, card_key, recipient, donation, state, note, created_at, updated_at ' +
        'FROM cards ORDER BY updated_at DESC, id DESC');
    const cards: CardRecord[] = [];
    try {
      while (resultSet.goToNextRow()) {
        cards.push(new CardRecord(
          resultSet.getLong(resultSet.getColumnIndex('id')),
          resultSet.getString(resultSet.getColumnIndex('card_key')),
          resultSet.getString(resultSet.getColumnIndex('recipient')),
          resultSet.getDouble(resultSet.getColumnIndex('donation')),
          resultSet.getString(resultSet.getColumnIndex('state')),
          resultSet.getString(resultSet.getColumnIndex('note')),
          resultSet.getLong(resultSet.getColumnIndex('created_at')),
          resultSet.getLong(resultSet.getColumnIndex('updated_at'))
        ));
      }
    } finally {
      resultSet.close();
    }
    return cards;
  }

  async importCards(context: common.Context, rows: CardDraft[], duplicateLines: number,
    invalidLines: number): Promise<ImportResult> {
    await this.initialize(context);
    const existingKeys: Set<string> = await this.keys(context);
    const fresh: CardDraft[] = [];
    let existing: number = 0;
    for (let i: number = 0; i < rows.length; i++) {
      if (existingKeys.has(rows[i].cardKey)) {
        existing += 1;
      } else {
        existingKeys.add(rows[i].cardKey);
        fresh.push(rows[i]);
      }
    }
    let added: number = 0;
    for (let start: number = 0; start < fresh.length; start += 100) {
      const buckets: relationalStore.ValuesBucket[] = [];
      const end: number = Math.min(start + 100, fresh.length);
      for (let i: number = start; i < end; i++) {
        const row: CardDraft = fresh[i];
        const bucket: relationalStore.ValuesBucket = {
          'card_key': row.cardKey,
          'recipient': row.recipient,
          'donation': row.donation,
          'state': row.state,
          'note': row.note,
          'created_at': row.createdAt,
          'updated_at': row.createdAt
        };
        buckets.push(bucket);
      }
      const count: number = await this.requireStore().batchInsert(CardRepository.TABLE, buckets);
      if (count < 0) {
        throw new Error('batch_insert_failed');
      }
      added += count;
    }
    return new ImportResult(added, existing, duplicateLines, invalidLines);
  }

  async insertCard(context: common.Context, draft: CardDraft): Promise<number> {
    await this.initialize(context);
    const now: number = Date.now();
    const bucket: relationalStore.ValuesBucket = {
      'card_key': draft.cardKey,
      'recipient': draft.recipient.trim(),
      'donation': draft.donation,
      'state': draft.state,
      'note': draft.note,
      'created_at': draft.createdAt > 0 ? draft.createdAt : now,
      'updated_at': now
    };
    const id: number = await this.requireStore().insert(
      CardRepository.TABLE, bucket, relationalStore.ConflictResolution.ON_CONFLICT_ABORT);
    if (id < 0) {
      throw new Error('insert_failed');
    }
    return id;
  }

  async updateCard(context: common.Context, card: CardRecord): Promise<void> {
    await this.initialize(context);
    const now: number = Date.now();
    const predicates: relationalStore.RdbPredicates =
      new relationalStore.RdbPredicates(CardRepository.TABLE);
    predicates.equalTo('id', card.id);
    const bucket: relationalStore.ValuesBucket = {
      'recipient': card.recipient.trim(),
      'donation': card.donation,
      'state': card.state,
      'note': card.note,
      'updated_at': now
    };
    const count: number = await this.requireStore().update(bucket, predicates);
    if (count !== 1) {
      throw new Error('update_failed');
    }
  }

  async deleteCard(context: common.Context, id: number): Promise<void> {
    await this.initialize(context);
    const predicates: relationalStore.RdbPredicates =
      new relationalStore.RdbPredicates(CardRepository.TABLE);
    predicates.equalTo('id', id);
    await this.requireStore().delete(predicates);
  }

  private async keys(context: common.Context): Promise<Set<string>> {
    const set: Set<string> = new Set<string>();
    const resultSet: relationalStore.ResultSet =
      await this.requireStore().querySql('SELECT card_key FROM cards');
    try {
      while (resultSet.goToNextRow()) {
        set.add(resultSet.getString(resultSet.getColumnIndex('card_key')));
      }
    } finally {
      resultSet.close();
    }
    return set;
  }

  private requireStore(): relationalStore.RdbStore {
    if (this.store === null) {
      throw new Error('database_not_initialized');
    }
    return this.store;
  }
}

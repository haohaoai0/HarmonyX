export class CardState {
  static readonly UNUSED: string = 'unused';
  static readonly USED: string = 'used';
  static readonly REVOKED: string = 'revoked';
}

export class CardRecord {
  id: number = 0;
  cardKey: string = '';
  recipient: string = '';
  donation: number = 0;
  state: string = CardState.UNUSED;
  note: string = '';
  createdAt: number = 0;
  updatedAt: number = 0;

  constructor(id: number, cardKey: string, recipient: string, donation: number, state: string,
    note: string, createdAt: number, updatedAt: number) {
    this.id = id;
    this.cardKey = cardKey;
    this.recipient = recipient;
    this.donation = donation;
    this.state = state;
    this.note = note;
    this.createdAt = createdAt;
    this.updatedAt = updatedAt;
  }
}

export class CardDraft {
  cardKey: string = '';
  recipient: string = '';
  donation: number = 0;
  state: string = CardState.UNUSED;
  note: string = '';
  createdAt: number = 0;

  constructor(cardKey: string, recipient: string, donation: number, state: string, note: string,
    createdAt: number) {
    this.cardKey = cardKey;
    this.recipient = recipient;
    this.donation = donation;
    this.state = state;
    this.note = note;
    this.createdAt = createdAt;
  }
}

export class RecipientSummary {
  name: string = '';
  cardCount: number = 0;
  usedCount: number = 0;
  donation: number = 0;

  constructor(name: string, cardCount: number, usedCount: number, donation: number) {
    this.name = name;
    this.cardCount = cardCount;
    this.usedCount = usedCount;
    this.donation = donation;
  }
}

export class CardStats {
  total: number = 0;
  unassigned: number = 0;
  assigned: number = 0;
  used: number = 0;
  revoked: number = 0;
  donation: number = 0;
  recipients: number = 0;

  constructor(cards: CardRecord[]) {
    const names: Set<string> = new Set<string>();
    for (let i: number = 0; i < cards.length; i++) {
      const card: CardRecord = cards[i];
      this.total += 1;
      this.donation += card.donation;
      if (card.state === CardState.USED) {
        this.used += 1;
      } else if (card.state === CardState.REVOKED) {
        this.revoked += 1;
      } else if (card.recipient.length === 0) {
        this.unassigned += 1;
      } else {
        this.assigned += 1;
      }
      if (card.recipient.length > 0) {
        names.add(card.recipient);
      }
    }
    this.recipients = names.size;
  }
}

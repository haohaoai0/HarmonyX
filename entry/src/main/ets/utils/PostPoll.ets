import type { PollOption, TweetPoll } from '../models/Tweet';

export function pollTotal(poll: TweetPoll): number {
  let total: number = 0;
  for (let i: number = 0; i < poll.options.length; i++) {
    total += poll.options[i].votes;
  }
  return total;
}

export function pollClosed(poll: TweetPoll, now: number): boolean {
  const end: number = Date.parse(poll.endsAt);
  return poll.countsAreFinal || (isFinite(end) && end <= now);
}

// Largest-remainder rounding keeps the displayed percentages at exactly 100.
export function pollPercentages(poll: TweetPoll): number[] {
  const total: number = pollTotal(poll);
  const result: number[] = [];
  const fractions: number[] = [];
  let sum: number = 0;
  for (let i: number = 0; i < poll.options.length; i++) {
    const percent: number = total > 0 ? poll.options[i].votes * 100 / total : 0;
    result.push(Math.floor(percent));
    fractions.push(percent - Math.floor(percent));
    sum += Math.floor(percent);
  }
  for (let remaining: number = total > 0 ? 100 - sum : 0; remaining > 0; remaining--) {
    let best: number = 0;
    for (let i: number = 1; i < fractions.length; i++) {
      if (fractions[i] > fractions[best]) { best = i; }
    }
    result[best]++;
    fractions[best] = -1;
  }
  return result;
}

export function copyPoll(poll: TweetPoll): TweetPoll {
  const options: PollOption[] = [];
  for (let i: number = 0; i < poll.options.length; i++) {
    const option: PollOption = poll.options[i];
    options.push({ id: option.id, label: option.label, votes: option.votes, imageUrl: option.imageUrl });
  }
  return {
    id: poll.id, cardUri: poll.cardUri, cardName: poll.cardName, api: poll.api,
    options: options, endsAt: poll.endsAt, durationMinutes: poll.durationMinutes,
    countsAreFinal: poll.countsAreFinal, countsKnown: poll.countsKnown,
    selectedChoice: poll.selectedChoice, imageUrl: poll.imageUrl
  };
}

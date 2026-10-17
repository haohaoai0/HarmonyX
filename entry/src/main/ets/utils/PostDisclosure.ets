import { PostDisclosure, PostPresentation } from '../models/PostContent';

export function isAdPost(presentation: PostPresentation | undefined): boolean {
  return presentation?.labels.some((label: PostDisclosure): boolean => label.kind === 'ad') === true;
}

// Promotion belongs to the feed occurrence. Detail refreshes can omit the
// feed wrapper while supplying newer notes or visibility information.
export function refreshedPostPresentation(current: PostPresentation | undefined,
  live: PostPresentation | undefined): PostPresentation | undefined {
  if (live === undefined) { return current; }
  if (!isAdPost(current) || isAdPost(live)) { return live; }
  const out: PostPresentation = new PostPresentation();
  out.note = live.note; out.visibility = live.visibility;
  out.labels = live.labels.concat(current?.labels.filter((label: PostDisclosure): boolean => label.kind === 'ad') ?? []);
  return out;
}

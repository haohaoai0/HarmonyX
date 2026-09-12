// Offline mock data so Harmony X is fully usable in the HarmonyOS
// emulator / previewer without X API credentials.
import type { Tweet, DirectMessage, AppNotification } from '../models/Tweet';

export class MockData {
  static timeline(): Tweet[] {
    return [
      {
        id: '1',
        author: { id: 'u1', name: 'HarmonyOS', username: 'HarmonyOS', avatarColor: '#1D9BF0', verified: true },
        text: 'Welcome to Harmony X on HarmonyOS 6.1! Native ArkTS, Stage model, API 24. This build runs the full timeline offline.',
        createdAt: '2h',
        metrics: { replyCount: 128, repostCount: 842, likeCount: 5210, viewCount: 210000 },
        liked: false,
        reposted: false
      },
      {
        id: '2',
        author: { id: 'u2', name: 'Harmony X', username: 'harmonyx', avatarColor: '#7856FF', verified: false },
        text: 'X/Twitter ported to HarmonyOS NEXT: tabs, compose, search, notifications, DMs. Sign in with X to see live posts.',
        createdAt: '4h',
        metrics: { replyCount: 42, repostCount: 156, likeCount: 980, viewCount: 45200 },
        liked: true,
        reposted: false
      },
      {
        id: '3',
        author: { id: 'u3', name: 'ArkUI', username: 'arkui_dev', avatarColor: '#00B578', verified: true },
        text: 'Tip: Harmony X targets HarmonyOS 6.1.1 (API 24) and is forward-compatible with HarmonyOS 7 (API 26) — no deprecated APIs, Stage model only.',
        createdAt: '7h',
        metrics: { replyCount: 18, repostCount: 64, likeCount: 412, viewCount: 18700 },
        liked: false,
        reposted: true
      },
      {
        id: '4',
        author: { id: 'u4', name: 'Dev Notes', username: 'devnotes', avatarColor: '#FF7A45', verified: false },
        text: 'Compose works offline: new posts prepend to the timeline instantly. With a token, POST /2/tweets publishes to X.',
        createdAt: '9h',
        metrics: { replyCount: 7, repostCount: 12, likeCount: 88, viewCount: 3200 },
        liked: false,
        reposted: false
      }
    ];
  }

  static trends(): string[] {
    return ['#HarmonyOS', '#HarmonyX', '#ArkTS', 'HDC 2026', '#HarmonyOS7', 'OpenHarmony'];
  }

  static notifications(): AppNotification[] {
    return [
      { id: 'n1', kind: '♥', text: 'HarmonyOS liked your post', time: '1h' },
      { id: 'n2', kind: '↻', text: 'ArkUI reposted your post', time: '3h' },
      { id: 'n3', kind: '+', text: 'Harmony X started following you', time: '1d' }
    ];
  }

  static messages(): DirectMessage[] {
    return [
      { id: 'm1', from: 'HarmonyOS', preview: 'API 24 build looks great!', time: '2h', unread: 2 },
      { id: 'm2', from: 'ArkUI', preview: 'Tabs + compose verified', time: '1d', unread: 0 },
      { id: 'm3', from: 'Harmony X', preview: 'Welcome to DMs', time: '2d', unread: 0 }
    ];
  }
}

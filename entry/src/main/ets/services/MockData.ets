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
        reposted: false,
        attachments: [
          {
            id: 'sample-mountain',
            type: 'photo',
            mediaUrl: 'https://images.unsplash.com/photo-1494526585095-c41746248156?auto=format&fit=crop&w=1200&q=85',
            previewUrl: '',
            width: 1200,
            height: 800,
            altText: 'Mountain landscape'
          }
        ]
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
        reposted: false,
        attachments: [
          {
            id: 'sample-video',
            type: 'video',
            mediaUrl: 'https://media.w3.org/2010/05/sintel/trailer.mp4',
            previewUrl: 'https://images.unsplash.com/photo-1497250681960-ef046c08a56e?auto=format&fit=crop&w=1200&q=85',
            width: 1280,
            height: 720,
            altText: 'Sample video'
          }
        ]
      }
    ];
  }

  // Keep signed-out browsing useful too: the home screen loads these batches
  // only after the reader reaches the end, just like the live API pages.
  static timelinePage(page: number): Tweet[] {
    if (page === 0) {
      return MockData.timeline();
    }
    if (page === 1) {
      return [
        {
          id: 'sample-5',
          author: { id: 'u5', name: 'OpenHarmony', username: 'openharmony', avatarColor: '#1677FF', verified: true },
          text: 'A smooth feed is more than a pretty list: request the next page before the reader reaches a dead end, and keep the cursor opaque.',
          createdAt: '11h',
          metrics: { replyCount: 23, repostCount: 97, likeCount: 634, viewCount: 12800 },
          liked: false,
          reposted: false
        },
        {
          id: 'sample-6',
          author: { id: 'u6', name: 'HarmonyOS Dev', username: 'hmos_dev', avatarColor: '#00A870', verified: true },
          text: 'ArkUI List pairs well with pull-to-refresh and onReachEnd. The former gets new posts; the latter continues into older posts.',
          createdAt: '13h',
          metrics: { replyCount: 31, repostCount: 120, likeCount: 846, viewCount: 23600 },
          liked: false,
          reposted: true
        },
        {
          id: 'sample-7',
          author: { id: 'u7', name: 'Native UI Notes', username: 'native_notes', avatarColor: '#8B5CF6', verified: false },
          text: 'A feed footer should communicate progress quietly: show a spinner while a page is in flight, then say when the reader has reached the end.',
          createdAt: '16h',
          metrics: { replyCount: 9, repostCount: 38, likeCount: 291, viewCount: 7400 },
          liked: false,
          reposted: false
        },
        {
          id: 'sample-8',
          author: { id: 'u8', name: 'Harmony X Lab', username: 'harmonyx_lab', avatarColor: '#F97316', verified: false },
          text: 'Offline mode now keeps the same continuous-reading rhythm as the connected feed, with additional sample posts loaded as you browse.',
          createdAt: '19h',
          metrics: { replyCount: 15, repostCount: 52, likeCount: 403, viewCount: 9600 },
          liked: false,
          reposted: false
        }
      ];
    }
    if (page === 2) {
      return [
        {
          id: 'sample-9',
          author: { id: 'u9', name: 'Mobile Performance', username: 'mobile_perf', avatarColor: '#E11D48', verified: true },
          text: 'Use a small page size and only append results. That keeps the reading position stable while the timeline grows.',
          createdAt: '1d',
          metrics: { replyCount: 18, repostCount: 74, likeCount: 512, viewCount: 15600 },
          liked: false,
          reposted: false
        },
        {
          id: 'sample-10',
          author: { id: 'u10', name: 'ArkTS Weekly', username: 'arkts_weekly', avatarColor: '#0EA5E9', verified: false },
          text: 'Avoid treating a failed next-page request as the end of the feed. The reader can retry by reaching the footer again.',
          createdAt: '1d',
          metrics: { replyCount: 12, repostCount: 45, likeCount: 326, viewCount: 8900 },
          liked: true,
          reposted: false
        },
        {
          id: 'sample-11',
          author: { id: 'u11', name: 'Design Systems', username: 'design_systems', avatarColor: '#14B8A6', verified: true },
          text: 'Continuous feeds still need a real end state. It reassures people that the app has finished loading rather than becoming unresponsive.',
          createdAt: '2d',
          metrics: { replyCount: 7, repostCount: 28, likeCount: 207, viewCount: 6100 },
          liked: false,
          reposted: false
        },
        {
          id: 'sample-12',
          author: { id: 'u12', name: 'Harmony Community', username: 'harmony_community', avatarColor: '#6366F1', verified: false },
          text: 'Thanks for trying Harmony X. Sign in to replace these samples with your own reverse-chronological X timeline.',
          createdAt: '2d',
          metrics: { replyCount: 20, repostCount: 65, likeCount: 488, viewCount: 11900 },
          liked: false,
          reposted: true
        }
      ];
    }
    return [];
  }

  static hasTimelinePage(page: number): boolean {
    return page >= 0 && page <= 2;
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

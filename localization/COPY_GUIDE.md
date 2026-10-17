# Harmony X interface copy

Write each string for its actual screen and action. Use the English resource as
a meaning reference, then check the Chinese source and the `.ets` usage when the
meaning is ambiguous. A `post` is an X publication; a chat `message` is a private
message. `Pin` means keep at the top, never block, lock, or unlock. A `server
draft` is a draft saved on X, not a server administration object.

Use the app's actual limits and behavior. Keep URLs, API names, brand names,
`%1$s`, `%1$d`, and other interpolation tokens intact. Preserve meaningful
leading/trailing spaces in fragments that are concatenated by existing code.
Keep each language internally consistent. Prefer a brief native action label
and a direct explanation over an English sentence reproduced word for word.

Interface names should follow the local X vocabulary:

| Language | Publication | Share again | Private messages |
| --- | --- | --- | --- |
| Traditional Chinese | 貼文 | 轉發 | 私人訊息 |
| French | post | repost | messages privés |
| German | Post | Repost | Direktnachrichten |
| Spanish | post | repost | mensajes directos |
| Brazilian Portuguese | post | repost | mensagens diretas |
| Italian | post | repost | messaggi diretti |
| Russian | публикация | репост | личные сообщения |
| Ukrainian | допис | репост | особисті повідомлення |
| Turkish | gönderi | yeniden gönderi | direkt mesajlar |
| Japanese | ポスト | リポスト | ダイレクトメッセージ |
| Korean | 게시물 | 재게시 | 쪽지 |
| Indonesian | postingan | posting ulang | pesan langsung |
| Malay | siaran | siaran semula | mesej langsung |
| Vietnamese | bài đăng | đăng lại | tin nhắn trực tiếp |
| Thai | โพสต์ | รีโพสต์ | ข้อความส่วนตัว |
| Arabic | منشور | إعادة النشر | الرسائل الخاصة |
| Persian | پست | بازنشر | پیام‌های خصوصی |
| Hindi | पोस्ट | रीपोस्ट | निजी संदेश |

Use language endonyms in the language picker, unchanged across languages. RTL
languages use the platform's reading direction. Mirror navigation chevrons and
logical leading/trailing insets; preserve the orientation of photos and videos.

The assemblers only write supplied copy or reuse an existing matching interface
label. Do not call an automatic translation service or ship its unreviewed output.

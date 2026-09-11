// X OAuth client configuration — the ONLY thing needed to enable live sign-in.
// 1. Create a free app at https://developer.x.com (Projects & Apps).
// 2. Enable OAuth 2.0 and add the callback URL exactly as shown:
//      opentwit://callback
//    (Type of App: Native App is the right choice for a public client.)
// 3. Paste the Client ID below and rebuild. No secret is needed: OpenTwit
//    uses the PKCE public-client flow, so end users never handle any key.
export const X_CLIENT_ID: string = '';

export function isOAuthConfigured(): boolean {
  return X_CLIENT_ID.trim().length > 0;
}

// A successful transport response is not a publication receipt. Only accept
// the created post at the mutation's documented result path, never an id from
// an author, quoted post, reply target, or arbitrary nested object.
export class XPostReceipt {
  ok: boolean = false;
  postId: string = '';
  errorCode: string = '';
  errorText: string = '';
  unconfirmed: boolean = false;
}

export class XPostResponse {
  static parse(status: number, body: string, graphql: boolean,
    mutationNames: string[] = ['create_tweet']): XPostReceipt {
    const receipt: XPostReceipt = new XPostReceipt();
    receipt.unconfirmed = status < 0 || (status >= 200 && status < 300);
    try {
      const root: Record<string, Object> = XPostResponse.object(JSON.parse(body) as Object);
      if (XPostResponse.readError(root, receipt)) {
        return receipt;
      }
      const data: Record<string, Object> = XPostResponse.object(root['data']);
      let post: Record<string, Object> = data;
      if (graphql) {
        const mutation: Record<string, Object> =
          XPostResponse.mutation(data, mutationNames);
        // APK u1q.java / esd.java: create_tweet.tweet_result.result.
        // The web operation variant uses the plural tweet_results wrapper.
        const results: Record<string, Object> =
          XPostResponse.object(mutation['tweet_result'] ?? mutation['tweet_results']);
        post = XPostResponse.object(results['result']);
        if (XPostResponse.readError(mutation, receipt) || XPostResponse.readError(results, receipt) ||
          XPostResponse.readError(post, receipt)) {
          return receipt;
        }
        if (post['__typename'] === 'TweetWithVisibilityResults') {
          post = XPostResponse.object(post['tweet']);
          if (XPostResponse.readError(post, receipt)) {
            return receipt;
          }
        }
        const type: string = XPostResponse.string(post['__typename']);
        if (type.length > 0 && type !== 'Tweet') {
          return receipt;
        }
      }
      const id: string = XPostResponse.string(post[graphql ? 'rest_id' : 'id']);
      // X ids must stay strings: their precision exceeds JavaScript integers.
      if (status >= 200 && status < 300 && /^[1-9][0-9]*$/.test(id)) {
        receipt.ok = true;
        receipt.postId = id;
        receipt.unconfirmed = false;
      }
      return receipt;
    } catch (error) {
      return receipt;
    }
  }

  private static object(value: Object | undefined): Record<string, Object> {
    if (value === undefined || value === null || typeof value !== 'object' || value instanceof Array) {
      return {};
    }
    return value as Record<string, Object>;
  }

  // CreateTweet, CreateNoteTweet and the undo-capable mutation all return the
  // same Tweet result shape, but the root field has changed across X clients.
  // Keep that variability at the boundary so callers still require a concrete
  // Tweet rest_id before reporting publication as successful.
  private static mutation(data: Record<string, Object>, names: string[]): Record<string, Object> {
    for (let i: number = 0; i < names.length; i++) {
      const candidate: Record<string, Object> = XPostResponse.object(data[names[i]]);
      if (Object.keys(candidate).length > 0) {
        return candidate;
      }
    }
    return {};
  }

  private static string(value: Object | undefined): string {
    return typeof value === 'string' ? value as string : '';
  }

  private static readError(node: Record<string, Object>, receipt: XPostReceipt): boolean {
    const errors: Object | undefined = node['errors'];
    let error: Record<string, Object> = {};
    if (errors instanceof Array && errors.length > 0) {
      error = XPostResponse.object(errors[0] as Object);
    } else if (errors !== undefined && errors !== null && !(errors instanceof Array)) {
      error = XPostResponse.object(errors);
    } else if (node['error'] !== undefined && node['error'] !== null) {
      error = XPostResponse.object(node['error']);
    } else {
      return false;
    }
    const extensions: Record<string, Object> = XPostResponse.object(error['extensions']);
    const code: Object | undefined = error['code'] ?? extensions['code'];
    receipt.errorCode = typeof code === 'string' || typeof code === 'number' ? String(code) : '';
    receipt.errorText = XPostResponse.string(error['message']);
    if (receipt.errorText.length === 0) {
      receipt.errorText = XPostResponse.string(node['error']);
    }
    receipt.errorText = receipt.errorText.substring(0, 500);
    receipt.unconfirmed = false;
    return true;
  }
}

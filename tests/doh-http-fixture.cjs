// Business-service tests keep their existing HTTP fake at the shared transport
// boundary. The real dispatcher/native event contract is tested separately in
// doh-http-request.test.cjs and by the signed device build.
function withDohHttpMock(dependencies) {
  if (!Object.hasOwn(dependencies, './DohHttpRequest')) {
    dependencies['./DohHttpRequest'] = {
      createDohHttpRequest() {
        const platform = dependencies['@ohos.net.http']?.default || dependencies['@ohos.net.http'] || dependencies['@kit.NetworkKit']?.http;
        if (!platform?.createHttp) throw Error('HTTP transport was not mocked by this service test');
        return platform.createHttp();
      }
    };
  }
  return dependencies;
}
module.exports = { withDohHttpMock };

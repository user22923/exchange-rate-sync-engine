@isTest
public class ExchangeRateApiMalformedMock implements HttpCalloutMock {

    public HttpResponse respond(HttpRequest request) {
        HttpResponse response = new HttpResponse();
        response.setStatusCode(200);
        response.setStatus('OK');
        response.setHeader('Content-Type', 'application/json');
        response.setBody('{"result":"error","error-type":"invalid-key"}');
        return response;
    }
}

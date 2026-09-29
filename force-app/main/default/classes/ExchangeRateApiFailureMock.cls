@isTest
public class ExchangeRateApiFailureMock implements HttpCalloutMock {

    public HttpResponse respond(HttpRequest request) {
        HttpResponse response = new HttpResponse();
        response.setStatusCode(503);
        response.setStatus('Service Unavailable');
        response.setBody('{"result":"error","error-type":"unknown"}');
        return response;
    }
}

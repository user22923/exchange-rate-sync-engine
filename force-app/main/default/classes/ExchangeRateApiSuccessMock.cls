@isTest
public class ExchangeRateApiSuccessMock implements HttpCalloutMock {

    public HttpResponse respond(HttpRequest request) {
        HttpResponse response = new HttpResponse();
        response.setStatusCode(200);
        response.setStatus('OK');
        response.setHeader('Content-Type', 'application/json');
        response.setBody(
            '{"result":"success","base_code":"USD","rates":{"USD":1,"EUR":0.92,"GBP":0.79,"JPY":149.5}}'
        );
        return response;
    }
}

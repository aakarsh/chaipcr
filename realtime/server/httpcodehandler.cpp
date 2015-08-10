#include "httpcodehandler.h"

HTTPCodeHandler::HTTPCodeHandler(Poco::Net::HTTPResponse::HTTPStatus status, const std::string &reason)
{
    setStatus(status);
    setReason(reason);
}

void HTTPCodeHandler::handleRequest(Poco::Net::HTTPServerRequest &/*request*/, Poco::Net::HTTPServerResponse &response)
{
    if (reason().empty())
        response.setStatusAndReason(status(), Poco::Net::HTTPServerResponse::getReasonForStatus(status()));
    else
        response.setStatusAndReason(status(), reason());

    response.send().flush();
}

return {
    service = "rest-api/service-file",
    resource = "file",
    endpoints = {
      {method = "GET", path = "/{[/.]*}", service_method = "GetFile"},
   }
}



function HomieDeleteDevice(device_name, async_response){
    if (window.confirm("Do you really want to delete device " + device_name + " ?")) {
        body = {}
        QueryPost("/device_deprecated/" + device_name + "/delete", body, async_response)
    }
}

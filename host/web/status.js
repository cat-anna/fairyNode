
function FairyNode_InitStatus() {
    bootstrap_code = `
        <div class="StatusGraphHolder">
            <div id="ModuleGraphDiv"></div>
        </div>
        <div class="StatusGraphHolder">
            <div id="ClassesGraphDiv"></div>
        </div>
`;

    node = document.getElementById('fairyNode-root');
    node.insertAdjacentHTML('afterend', bootstrap_code);
}

function HandleGraph(div_id, data) {
    var id = "#" + div_id
    if ($(id).attr("src") != data.url) {
        console.log("Url changed: " + div_id + " -> " + data.url)
        AsyncRequest(data.url, function (response) {
            $(id).html(response)
            $(id).attr("src", data.url)
        })
    }
}

function refresh() {
    QueryGet("/status/modules/graph/url", function (data) { HandleGraph("ModuleGraphDiv", data) })
    QueryGet("/status/classes/graph/url", function (data) { HandleGraph("ClassesGraphDiv", data) })
}

function FairyNodeStart() {
    FairyNode_InitStatus()

    refresh();
    setInterval(refresh, 5000);
}

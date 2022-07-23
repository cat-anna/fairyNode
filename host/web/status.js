
function FairyNode_InitStatus() {
    bootstrap_code = `
        <div class="StatusGraphHolder">
            <div id="ModuleGraphDiv"></div>
        </div>
        <div class="StatusGraphHolder">
            <div id="ClassesGraphDiv"></div>
        </div>

        <div class="StatTableHolder">
            Scheduler
            <table id="SchedulerStats" class="StatTable"></table>
        </div>
        <div class="StatTableHolder">
            EventBusStats
            <table id="EventBusStats" class="StatTable"></table>
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

function HandleStatTableAddRow(table, data, header) {
    let tr = table.insertRow();
    data.forEach(function (col, i) {
        let td = tr.insertCell();
        if(header != null && header[i].endsWith("_timestamp")) {
            td.innerHTML = new Date(col * 1000).toLocaleString() + "." + pad(Math.floor((col * 1000)%1000), 3);
        } else {
            td.innerHTML = col;
        }
    });
}

function HandleStatTable(div_id, data) {
    var div = $("#" + div_id).html("")
    var table = document.getElementById(div_id)
    if (data.table) {
        HandleStatTableAddRow(table, data.table.header)
        for (let row of data.table.data) {
            HandleStatTableAddRow(table, row, data.table.header)
        }
    }
}

function refresh() {
    QueryGet("/status/modules/graph/url", function (data) { HandleGraph("ModuleGraphDiv", data) })
    QueryGet("/status/classes/graph/url", function (data) { HandleGraph("ClassesGraphDiv", data) })
    QueryGet("/status/stats/scheduler", function (data) { HandleStatTable("SchedulerStats", data) })
    QueryGet("/status/stats/base_event_bus", function (data) { HandleStatTable("EventBusStats", data) })
}

function FairyNodeStart() {
    FairyNode_InitStatus()

    refresh();
    setInterval(refresh, 5000);
}

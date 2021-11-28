
var kMissingValueBlock = "<span class='MissingValue'>&lt;&nbsp;?&nbsp;&gt;<span>"

function FairyNode_InitOverview() {
    bootstrap_code = `
    <div id="OverviewOuter">
        <div id="OverviewInner">
            <div id="DeviceListRoot" class="OverviewTable">
                <div id="DeviceList" class="DeviceListNodes"></div>
                <div id="DeviceListContent" class="DeviceListContent">
                    <div id="OverviewTable" class="DeviceListPages tabcontent tab_active">
                        <div id="OverviewTable" class="OverviewTable">
                        </div>
                    </div>
                </div>
            </div>

        </div>
    </div>
    `;

    node = document.getElementById('fairyNode-root');
    node.insertAdjacentHTML('afterend', bootstrap_code);

    var row = SetOverviewRow("Head", {
        // ip : "Ip",
        state: "State",
        timestamp: "LFS timestamp",
        uptime: "Uptime",
        wifi: "Signal",
        release: "NodeMCU | FairyNode version",
        errors: {
            header: true,
            caption: "Errors",
            value: null
        }
    })

    $(row).addClass("OverviewTableHead")

    var device = GetOrCreateDiv("DEVICE_HEAD", "DeviceList", "DeviceListEntry Header tab_button tab_header")
    $(device).html("Node name")

    $(device).click(function() {
        $(".DeviceListPages.tab_active").removeClass("tab_active")
        $("#OverviewTable").addClass("tab_active")
        $(".DeviceListPages.tab_button_active").removeClass("tab_button_active")
    });
}

function SortedKeys(unordered) {
    if (unordered == null) {
        return {}
    }
    return Object.keys(unordered).sort().reduce(
        (obj, key) => {
        obj[key] = unordered[key];
        return obj;
        },
        {}
    );
}

function SetOverviewRow(id, values) {
    var row_id = "ROW_" + id;
    var row = GetOrCreateDiv(row_id, "OverviewTable", "OverviewTableRow")

    var state = GetOrCreateDiv("STATE_" + id, row_id, "OverviewTableEntry OverviewTableNodeState")
    $(state).html(values.state)
    $(state).removeClass(function(index, className) {
        return (className.match(/(^|\s)NodeState-\S+/g) || []).join(' ');
    });
    $(state).addClass("NodeState-" + values.state)

    var err_base = GetOrCreateDiv("ERROR_" + id, row_id, "OverviewTableEntry OverviewTableNodeErrors")
    var err_inner = GetOrCreateDiv("ERROR_INNER_" + id, "ERROR_" + id, "FN_tooltip")
    $(err_inner).html(values.errors.caption)
    if (values.errors.value) {
        var err_inner = GetOrCreateDiv("ERROR_TIP_" + id, "ERROR_INNER_" + id, "FN_tooltiptext", { type: "span" }).html(values.errors.value)
        $(err_base).addClass("NodeError-Active")
        $(err_base).removeClass("NodeError-None")
    } else {
        if (values.errors.header) {
            //nothing
        } else {
            $(err_base).addClass("NodeError-None")
            $(err_base).removeClass("NodeError-Active")
        }
    }

    var row_class = "OverviewTableEntry "
    var fw_class = "OverviewTableNodeFWTimestamp"
    var uptime_class = "OverviewTableNodeUptime"
    var wifi_class = "OverviewTableNodeWifi"
    var space_class = "OverviewTableNodeSpace"
    var release_class = "OverviewTableNodeRelease"

    // var ip = GetOrCreateDiv("IP_" + id, row_id, "OverviewTableEntry OverviewTableNodeIp")
    // $(ip).html(values.ip)

    GetOrCreateDiv("UPTIME_" + id, row_id, row_class + uptime_class).html(values.uptime)
    GetOrCreateDiv("FW_TIMESTAMP_" + id, row_id, row_class + fw_class).html(values.timestamp)
    GetOrCreateDiv("RELEASE_" + id, row_id, row_class + release_class).html(values.release)
    GetOrCreateDiv("WIFI_" + id, row_id, row_class + wifi_class).html(values.wifi)
    GetOrCreateDiv("SPACE_" + id, row_id, row_class + space_class, { html: "&nbsp; " })

    return row
}

function newDate(timestamp) {
    return moment.unix(timestamp).toDate();
}

function RefreshChart(chart) {
    console.log(chart.source_url)
    QueryGet(chart.source_url, function(data) {
        console.log(data)
        data.history.sort(function(a, b) { return a.timestamp < b.timestamp; })
        chart.config.data.datasets[0].label = data.label + " (" + data.history.length + " samples)"

        for (var key in data.history) {
            var item = data.history[key]
            if(chart.last_timestamp < item.timestamp) {
                chart.config.data.labels.push(newDate(item.timestamp));
                chart.config.data.datasets[0].data.push({
                    x: newDate(item.timestamp),
                    y: parseFloat(item.value),
                });
                chart.last_timestamp = item.timestamp
            }
        }
        chart.update();
    })
}
function OpenDevicePropertyChart(url, parent_block) {
    var chart_div_id = "CHART_" + parent_block
    var exists = document.getElementById(chart_div_id) !== null
    var open_chart = GetOrCreateDivAfter(chart_div_id, parent_block, "DeviceNodePropertyEntry DeviceNodePropertyChartBlock", { html: "&nbsp"})

    if (exists) {
        console.log("toggle")
        $('#'+chart_div_id).toggle();
        return
    }

    var canvas_id = "CANVAS_" + parent_block
    var canvas = document.createElement('canvas');
    $(canvas)
        .attr('id', canvas_id)
        .toggleClass("DeviceNodePropertyChart")
        .text('unsupported browser')
        .appendTo("#" + chart_div_id);

    var timeFormat = 'MM/DD/YYYY HH:mm';

    function newDateString(days) {
        return moment().add(days, 'd').format(timeFormat);
    }
    var ctx = canvas.getContext('2d');
    var myChart = new Chart(ctx, {
        type: 'line',
        data: {
            labels: [],
            datasets: [{
                label: '?',
                borderColor: 'rgb(50, 50, 50)',
                backgroundColor: 'rgb(150, 150, 150)',
                fill: false,
                data: [],
            }]
        },
        options: {
            legend: {
                labels: {
                    fontColor: 'rgb(150, 150, 150)',
                }
            },
            scales: {
                xAxes: [{
                    type: 'time',
                    time: {
                        parser: timeFormat,
                        tooltipFormat: 'll HH:mm'
                    },
                    ticks: {
                        fontColor: 'rgb(150, 150, 150)',
                        maxTicksLimit: 20,
                    },
                    scaleLabel: {
                        fontColor: 'rgb(150, 150, 150)',
                        display: true,
                        labelString: 'Date'
                    }
                }],
                yAxes: [{
                    ticks: {
                        fontColor: 'rgb(150, 150, 150)',
                    },
                    scaleLabel: {
                        fontColor: 'rgb(150, 150, 150)',
                        display: true,
                        labelString: 'value'
                    }
                }]
            },
        }
    });

    myChart.last_timestamp = 0
    myChart.source_url = url

    RefreshChart(myChart)
    setInterval(function(){ RefreshChart(myChart) }, 10 * 1000)
}

function SetDeviceNodesPage(entry, sub_id, body_id) {

    var $root_elem = $("#" + body_id)
    var first = $root_elem.length == 0

    var page = GetOrCreateDiv(body_id, sub_id, " DevicePageContent DevicePage tabcontent tab_inactive")

    function check_value(v, empty) {
        if (v != null) return v;
        if (empty != null) return empty;
        return kMissingValueBlock;
    }

    const ordered = Object.keys(entry.nodes).sort().reduce(
        (obj, key) => {
          obj[key] = entry.nodes[key];
          return obj;
        },
        {}
      );

    for (var key in SortedKeys(entry.nodes)) {
        node = entry.nodes[key]
        var node_id = key + "_NODE_" + body_id
        GetOrCreateDiv(node_id, body_id, "DeviceNode")
        GetOrCreateDiv("HEADER_" + node_id, node_id, "DeviceNodeHeader").html(node.name)

        for (var prop_key in SortedKeys(node.properties)) {
            var prop = node.properties[prop_key]
            var prop_id = prop_key + "_" + node_id
            GetOrCreateDiv(prop_id, node_id, "DeviceNodePropertyContent")

            if(prop.datatype == "float" || prop.datatype == "integer" || prop.datatype == "boolean" || prop.datatype == "number") {
                var chart_source = "/device/" + entry.name + "/history/" + node.id + "/" + prop.id
                var chart_node_id = "CHART_BTN_" + prop_id
                var open_chart = GetOrCreateDiv(chart_node_id, prop_id, "DeviceNodePropertyEntry DeviceNodePropertyOpenChart", { html: "&nbsp"})
                $(open_chart).attr("data-url", chart_source)
                $(open_chart).attr("prop-id", prop_id)
                $(open_chart).unbind('click').click(function() {
                    OpenDevicePropertyChart($(this).attr("data-url"), $(this).attr("prop-id"), this)
                })
            } else {
                GetOrCreateDiv("SPACER_" + prop_id, prop_id, "DeviceNodePropertyEntry DeviceNodePropertySpacer", { html: "&nbsp" })
            }

            GetOrCreateDiv("HEADER_" + prop_id, prop_id, "DeviceNodePropertyEntry DeviceNodePropertyName", { html: prop.name })
            GetOrCreateDiv("VALUE_" + prop_id, prop_id, "DeviceNodePropertyEntry DeviceNodePropertyValue").html(check_value(prop.value) + " " + check_value(prop.unit, "") )
            var timestamp = null
            if (prop.timestamp != null){
                timestamp = new Date(prop.timestamp * 1000).toLocaleString()
            }
            GetOrCreateDiv("TIMESTAMP_" + prop_id, prop_id, "DeviceNodePropertyEntry DeviceNodePropertyTimestamp").html(check_value(timestamp))

            if (prop.settable != true) {
                GetOrCreateDiv("SETTABLE_" + prop_id, prop_id, "DeviceNodePropertyEntry DeviceNodePropertySettable").html("&nbsp")
            } else {
                var control_id = "SETTABLE_" + prop_id
                if (first) {
                    if (prop.datatype == "boolean") {
                        var checkbox = GetOrCreateDiv(control_id, prop_id, "", {
                            classes: "DeviceNodePropertyEntry DeviceNodePropertySettable",
                            type: "input type='checkbox'"
                        })
                        var url = "/device/" + entry.name + "/node/" + node.id + "/" + prop.id
                        $(checkbox).attr("data-url", url)
                        $(checkbox).prop('checked', prop.value)
                        $(checkbox).change(function() {
                            console.log("CHANGE " + $(this).attr("data-url"))
                            body = {}
                            if ($(this).is(":checked")) {
                                body.value = true
                            } else {
                                body.value = false
                            }
                            QueryPost($(this).attr("data-url"), body)
                            setTimeout(refresh, 3000);
                        });
                    } else if (prop.datatype == "number" || prop.datatype == "float" || prop.datatype == "integer") {
                        var checkbox = GetOrCreateDiv(control_id, prop_id, "", {
                            classes: "DeviceNodePropertyEntry DeviceNodePropertySettable DeviceNodePropertySettableNumber",
                            type: "input type='number'"
                        })
                        var url = "/device/" + entry.name + "/node/" + node.id + "/" + prop.id
                        $(checkbox).attr("data-url", url)
                        $(checkbox).prop('value', prop.value)
                        $(checkbox).change(function() {
                            console.log("CHANGE " + $(this).attr("data-url"))
                            body = {}
                            body.value = $(this).prop("value")
                            QueryPost($(this).attr("data-url"), body)
                            setTimeout(refresh, 3000);
                        });
                    }
                } else {
                    if (prop.datatype == "boolean") {
                        $("#" + control_id).prop('checked', prop.value)
                    } else {
                        $("#" + control_id).prop('value', prop.value)
                    }
                }
            }
        }
    }
    return page
}

function SetDeviceInfoPageStatus(entry, body_id) {
    var node_id = "DEVICESTATUS_" + body_id
    GetOrCreateDiv(node_id, body_id, "DeviceNode")
    GetOrCreateDiv("HEADER_" + node_id, node_id, "DeviceNodeHeader").html("Device status")

    var blocks = [
        ["State", entry.state],
        // ["Root", "fw/FairyNode/root/timestamp", ],
        // ["NodeMcu release", "fw/NodeMcu/git_release", ],
    ]

    var nodes = entry.nodes
    var sysinfo_props
    if (nodes) {
        sysinfo = nodes.sysinfo
        if (sysinfo) {
            sysinfo_props = sysinfo.properties
            blocks.push(["Uptime", FormatSeconds(sysinfo_props.uptime.value), ])
        }
    }


    if (sysinfo_props != null && sysinfo_props.free_space != null) {
        free_space = (sysinfo_props.free_space.value / 1024).toFixed(1) + " kib"
        blocks.push(
            ["Flash free space", free_space]
        )
    }

    for (var i in SortedKeys(blocks)) {
        var block = blocks[i]

        var caption = block[0]
        var value = block[1]
        var id = caption.split(" ").join("_")

        if (/timestamp$/.test(value)) {
            value = (new Date(value * 1000)).toLocaleString()
        }

        var prop_id = id + "_" + node_id
        GetOrCreateDiv(prop_id, node_id, "DeviceNodePropertyContent")
            // GetOrCreateDiv("SPACER_" + prop_id, prop_id, "DeviceNodePropertyEntry DeviceNodePropertySpacer", { html: "&nbsp" })
        GetOrCreateDiv("HEADER_" + prop_id, prop_id, "DeviceNodePropertyEntry DeviceNodePropertyName", { html: caption })
        GetOrCreateDiv("VALUE_" + prop_id, prop_id, "DeviceNodePropertyEntry DeviceNodePropertyValue").html(value)
    }

    var state_block_id = "#" + "VALUE_" + blocks[0][0] + "_" + node_id
    $(state_block_id).removeClass(function(index, className) {
        return (className.match(/(^|\s)NodeState-\S+/g) || []).join(' ');
    });
    $(state_block_id).addClass("NodeState-" + entry.state)
}

function SetDeviceInfoPageSwVersion(entry, body_id) {
    var node_id = "SW_VERSION_" + body_id
    GetOrCreateDiv(node_id, body_id, "DeviceNode")
    var header = GetOrCreateDiv("HEADER_" + node_id, node_id, "DeviceNodeHeader")
    header.html("<div style='float: left; display: block; padding-right:20px;'>Software version</div>")
    jQuery('<div/>', {
        // id: 'some-id',
        "class": 'OtaTriggerButton',
        html: 'Trigger OTA',
        "data-url" : "/device/" + entry.name + "/command",
        click: function() {
            body = {
                command: 'sys,ota,update',
            }
            QueryPost($(this).attr("data-url"), body)
        }
    }).appendTo(header);

    var blocks = [
        ["Configuration", "fw/FairyNode/config/timestamp", ],
        ["LFS", "fw/FairyNode/lfs/timestamp", ],
        ["Root", "fw/FairyNode/root/timestamp", ],
        ["FairyNode version", "fw/FairyNode/version", ],
        ["NodeMcu release", "fw/NodeMcu/git_release", ],
        ["NodeMcu branch", "fw/NodeMcu/git_branch", ],
    ]

    for (var i in SortedKeys(blocks)) {
        var block = blocks[i]

        var caption = block[0]
        var var_name = block[1]

        var value = entry.variables[var_name] || "-"
        var id = var_name.split("/").join("")

        if (/timestamp$/.test(var_name)) {
            value = (new Date(value * 1000)).toLocaleString()
        }

        var prop_id = id + "_" + node_id
        GetOrCreateDiv(prop_id, node_id, "DeviceNodePropertyContent")
            // GetOrCreateDiv("SPACER_" + prop_id, prop_id, "DeviceNodePropertyEntry DeviceNodePropertySpacer", { html: "&nbsp" })
        GetOrCreateDiv("HEADER_" + prop_id, prop_id, "DeviceNodePropertyEntry DeviceNodePropertyName", { html: caption })
        GetOrCreateDiv("VALUE_" + prop_id, prop_id, "DeviceNodePropertyEntry DeviceNodePropertyValue").html(value)
    }
}

function SetDeviceInfoPageVariables(entry, body_id) {
    var node_id = "VARIABLE_" + body_id
    GetOrCreateDiv(node_id, body_id, "DeviceNode")
    GetOrCreateDiv("HEADER_" + node_id, node_id, "DeviceNodeHeader").html("Variables")

    var keys = Object.keys(entry.variables)
    keys.sort()
    for (var i in SortedKeys(keys)) {
        var key = keys[i]
        var value = entry.variables[key]
        var id = key.split("/").join("")

        var prop_id = id + "_" + node_id
        GetOrCreateDiv(prop_id, node_id, "DeviceNodePropertyContent")
            // GetOrCreateDiv("SPACER_" + prop_id, prop_id, "DeviceNodePropertyEntry DeviceNodePropertySpacer", { html: "&nbsp" })
        GetOrCreateDiv("HEADER_" + prop_id, prop_id, "DeviceNodePropertyEntry DeviceNodePropertyName", { html: key })
        GetOrCreateDiv("VALUE_" + prop_id, prop_id, "DeviceNodePropertyEntry DeviceNodePropertyValue").html(value)
    }
}

function SetDeviceInfoPageActiveErrors(entry, body_id) {
    var node_id = "ERRORS_" + body_id
    GetOrCreateDiv(node_id, body_id, "DeviceNode")

    var error_dict = null
    if (entry.nodes.sysinfo != null && entry.nodes.sysinfo.properties.errors != null) {
        error_dict = entry.nodes.sysinfo.properties.errors.value_parsed
    }

    $("#" + node_id).html("")
    if (error_dict == null) {
        GetOrCreateDiv("HEADER_" + node_id, node_id, "DeviceNodeHeader").html("No active errors")
        return
    }

    GetOrCreateDiv("HEADER_" + node_id, node_id, "DeviceNodeHeader DeviceInfoErrorsActive").html("Active errors")

    var keys = Object.keys(error_dict)
    keys.sort()
    for (var i in SortedKeys(keys)) {
        var key = keys[i]
        var value = error_dict[key]

        var prop_id = i + "_" + node_id
        GetOrCreateDiv(prop_id, node_id, "DeviceNodePropertyErrorContent")

        var title_prop_id = i + "_title_" + node_id

        GetOrCreateDiv(title_prop_id, prop_id, "DeviceNodePropertyErrorTitle")

        var kill = GetOrCreateDiv("KILL_" + prop_id, title_prop_id, "DeviceNodePropertyErrorEntry DeviceNodePropertyErrorBlock DeviceNodePropertyErrorClickableIcon", { html: "&nbsp;"})

        $(kill).attr("device", entry.name)
        $(kill).attr("key", key)
        $(kill).click(function() {
            body = {
                command: "clear_error",
                args : {
                    key : $(this).attr("key"),
                }
            }
            url = "/device/" + $(this).attr("device") + "/command"
            QueryPost(url, body)
        })

        GetOrCreateDiv("HEADER_" + prop_id, title_prop_id, "DeviceNodePropertyErrorEntry DeviceNodePropertyErrorBlock", { html: key })

        GetOrCreateDiv("VALUE_" + prop_id, prop_id, "DeviceNodePropertyErrorEntry DeviceNodePropertyErrorMessage").html(value)
    }
}

function SetDeviceInfoPage(entry, sub_id, body_id) {
    var page = GetOrCreateDiv(body_id, sub_id, "DevicePageContent DevicePage tabcontent tab_inactive")
    SetDeviceInfoPageStatus(entry, body_id)
    SetDeviceInfoPageSwVersion(entry, body_id)
    SetDeviceInfoPageActiveErrors(entry, body_id)
    SetDeviceInfoPageVariables(entry, body_id)
    return page
}

function SetDeviceCmdPage(entry, sub_id, body_id) {
    var page = GetOrCreateDiv(body_id, sub_id, "DevicePageContent DevicePage tabcontent tab_inactive")

    return page
}

function UpdateDevice(entry) {
    var vars = entry.variables

    var nodes = entry.nodes

    var sysinfo
    var sysinfo_props
    if (nodes) {
        sysinfo = nodes.sysinfo
        if (sysinfo) {
            sysinfo_props = sysinfo.properties
        }
    }

    var timestamp_value = vars["fw/FairyNode/lfs/timestamp"] || vars["fw/timestamp"]
    var timestamp = ""
    if(timestamp_value) {
        timestamp = new Date(timestamp_value * 1000)
    }

    var err_caption
    var err_value = null
    if(sysinfo_props != null && sysinfo_props.errors != null){
        var err_current = sysinfo_props.errors.value

        var error_dict = {}
        try {
            error_dict = JSON.parse(err_current)
        }
        catch(e) { }

        if (Array.isArray(error_dict) || Object.keys(error_dict).length == 0) {
            error_dict = null
        }
        sysinfo_props.errors.value_parsed = error_dict

        if (error_dict == null) {
            err_caption = "&nbsp;"
        } else {
            err_caption = "Active"
            err_value = err_current
        }
    }

    var my_class = "Device_" + entry.name
    var $root_elem = $("#DEVICE_" + entry.name)
    var first = $root_elem.length == 0

    var device = GetOrCreateDiv("DEVICE_" + entry.name, "DeviceList", "DeviceListPages DeviceList DeviceListEntry tab_button", { html: entry.name })

    if (first) {
        $(device).click(function() {
            $(".DeviceListPages.tab_active").removeClass("tab_active")
            $(".DeviceListPages.tab_button_active").removeClass("tab_button_active")
            $("#" + "DEVICE_PAGE_" + entry.name).removeClass("tab_inactive").addClass("tab_active")
            $(device).addClass("tab_button_active")
        });
    }

    var uptime = null
    var wifi = null
    if (sysinfo_props != null && sysinfo_props.uptime != null)
        uptime = sysinfo_props.uptime.value
    if (sysinfo_props != null && sysinfo_props.wifi != null)
        wifi = sysinfo_props.wifi.value + "%"

    if(uptime) {
        uptime = FormatSeconds(uptime)
    } else {
        uptime = ""
    }

    SetOverviewRow(entry.name, {
        // ip : vars.localip,
        state: entry.state,
        timestamp: timestamp.toLocaleString(),
        uptime: uptime,
        wifi: wifi,
        release: (vars["fw/NodeMcu/git_release"] || vars["fw/NodeMcu/git_branch"] ) + " | " +
            (vars["fw/FairyNode/version"] ),
        errors: {
            caption: err_caption,
            value: err_value,
        }
    })

    var sub_id = "DEVICE_PAGE_" + entry.name
    GetOrCreateDiv(sub_id, "DeviceListContent", "DeviceListPages tabcontent tab_inactive")
    GetOrCreateDiv("HEADER_" + sub_id, sub_id, "Header DevicePageHeader", { html: entry.name })

    var pages_id = "DEVICE_PAGE_CONTENT_" + sub_id
    GetOrCreateDiv(pages_id, sub_id, "DevicePageBar")

    var btns = [
        GetOrCreateDiv("NODES_" + pages_id, pages_id, my_class + " DevicePage DevicePageButton tab_button tab_button_active", { html: "Nodes", data: "NODES" }),
        GetOrCreateDiv("INFO_" + pages_id, pages_id, my_class + " DevicePage DevicePageButton tab_button", { html: "Device info", data: "INFO" }),
        GetOrCreateDiv("CMD_" + pages_id, pages_id, my_class + " DevicePage DevicePageButton tab_button", { html: "Commands", data: "CMD" }),
    ]
    if (first)
        for (var i in btns) {
            $(btns[i]).click(function(event) {
                $(".DevicePage.tab_active." + my_class).removeClass("tab_active")
                $(".DevicePage.tab_button_active." + my_class).removeClass("tab_button_active")
                $("#" + $(this).attr("data") + "_" + sub_id).addClass("tab_active")
                $(this).addClass("tab_button_active")
            });
        }

    var pages = [
        SetDeviceNodesPage(entry, sub_id, "NODES_" + sub_id),
        SetDeviceInfoPage(entry, sub_id, "INFO_" + sub_id),
        SetDeviceCmdPage(entry, sub_id, "CMD_" + sub_id),
    ]
    if (first) {
        for (var i in pages) {
            $(pages[i]).addClass(my_class)
        }
        $(pages[0]).removeClass("tab_inactive").addClass("tab_active")
    }
}

function HandleDeviceResponse(data) {
    data.sort(function(a, b) {
        if (a.name < b.name) {
            return -1;
        }
        if (a.name > b.name) {
            return 1;
        }
        return 0;
    })
    console.log(data)

    data.forEach(function(entry) {
        UpdateDevice(entry);
    });
}

function refresh() {
    QueryGet("/device", function(data) { HandleDeviceResponse(data) })
}

function FairyNodeOverviewStart() {
    FairyNode_InitOverview()

    refresh();
    setInterval(refresh, 5000);
}
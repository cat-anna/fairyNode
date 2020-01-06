function FairyNode_InitOverview() {
    bootstrap_code = `
    <div id="OverviewOuter">
        <div id="OverviewInner">
            <div id="DeviceListRoot" class="OverviewTable">
                <div id="DeviceList" class="DeviceListNodes"></div>
                <div id="DeviceListContent" class="DeviceListContent">
                    <div id="OverviewTable" class="tabcontent tab_active">
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
        timestamp: "Firmware timestamp",
        uptime: "Uptime",
        wifi: "Signal",
        // release : "Node version",
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
        $(".tab_active").removeClass("tab_active")
        $("#OverviewTable").addClass("tab_active")
        $(".tab_button_active").removeClass("tab_button_active")
    });
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
        // var ip = GetOrCreateDiv("IP_" + id, row_id, "OverviewTableEntry OverviewTableNodeIp")
        // $(ip).html(values.ip)

    GetOrCreateDiv("FW_TIMESTAMP_" + id, row_id, row_class + fw_class).html(values.timestamp)
    GetOrCreateDiv("UPTIME_" + id, row_id, row_class + uptime_class).html(values.uptime)
    GetOrCreateDiv("WIFI_" + id, row_id, row_class + wifi_class).html(values.wifi)
    GetOrCreateDiv("SPACE_" + id, row_id, row_class + space_class, { html: "&nbsp; " })

    return row
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

    var timestamp = new Date(vars["fw/timestamp"] * 1000)

    var err_caption
    var err_value = null
    var err_current = sysinfo_props.errors.value
    if (err_current == "[]") {
        err_caption = "&nbsp;"
    } else {
        err_caption = "Active"
        err_value = err_current
    }

    var device = GetOrCreateDiv("DEVICE_" + entry.name, "DeviceList", "DeviceList DeviceListEntry tab_button", { html: entry.name })

    $(device).click(function() {
        $(".tab_active").removeClass("tab_active")
        $(".tab_button_active").removeClass("tab_button_active")
        $("#" + "DEVICE_PAGE_" + entry.name).addClass("tab_active")
        $(device).addClass("tab_button_active")
    });

    SetOverviewRow(entry.name, {
        // ip : vars.localip,
        state: entry.state,
        timestamp: timestamp.toLocaleString(),
        uptime: FormatSeconds(sysinfo_props.uptime.value),
        wifi: sysinfo_props.wifi.value + "%",
        // release : vars["fw/nodemcu/git_release"],
        errors: {
            caption: err_caption,
            value: err_value,
        }
    })

    var sub_id = "DEVICE_PAGE_" + entry.name
    GetOrCreateDiv(sub_id, "DeviceListContent", "tabcontent tab_inactive")
    GetOrCreateDiv("HEADER_" + sub_id, sub_id, "Header DevicePageHeader", { html: entry.name })

    var body_id = "BODY_" + sub_id
    GetOrCreateDiv(body_id, sub_id, "DevicePageContent")

    function check_value(v, empty) {
        if (v != null) return v;
        if (empty != null) return empty;
        return "<span class='MissingValue'>&lt;&nbsp;?&nbsp;&gt;<span>";
    }

    for (var key in nodes) {
        node = nodes[key]
        var node_id = key + "_NODE_" + sub_id
        GetOrCreateDiv(node_id, body_id, "DeviceNode")
        GetOrCreateDiv("HEADER_" + node_id, node_id, "DeviceNodeHeader").html(node.name)

        for (var prop_key in node.properties) {
            var prop = node.properties[prop_key]
            var prop_id = prop_key + "_" + node_id
            GetOrCreateDiv(prop_id, node_id, "DeviceNodePropertyContent")
                // GetOrCreateDiv("SPACER_" + prop_id, prop_id, "DeviceNodePropertyEntry DeviceNodePropertySpacer", { html: "&nbsp" })
            GetOrCreateDiv("HEADER_" + prop_id, prop_id, "DeviceNodePropertyEntry DeviceNodePropertyName", { html: prop.name })
            GetOrCreateDiv("VALUE_" + prop_id, prop_id, "DeviceNodePropertyEntry DeviceNodePropertyValue").html(check_value(prop.value))
            var timestamp = null
            if (prop.timestamp != null)
                timestamp = new Date(prop.timestamp * 1000).toLocaleString()
            GetOrCreateDiv("TIMESTAMP_" + prop_id, prop_id, "DeviceNodePropertyEntry DeviceNodePropertyTimestamp").html(check_value(timestamp))

            if (prop.settable != true) {
                GetOrCreateDiv("SETTABLE_" + prop_id, prop_id, "DeviceNodePropertyEntry DeviceNodePropertySettable").html("&nbsp")
            } else {
                if (prop.datatype == "boolean") {
                    var checkbox = GetOrCreateDiv("SETTABLE_" + prop_id, prop_id, "", {
                        classes: "DeviceNodePropertyEntry DeviceNodePropertySettable",
                        type: "input type='checkbox'"
                    })
                    var url = "/device/" + entry.name + "/node/" + node.id + "/" + prop.id
                    $(checkbox).attr("data-url", url)
                    $(checkbox).prop('checked', prop.value == "true")
                    $(checkbox).change(function() {
                        var url = url; // j is a copy of i only available to the scope of the inner function
                        body = {}
                        if ($(this).is(":checked")) {
                            body.value = true
                        } else {
                            body.value = false
                        }
                        QueryPost($(this).attr("data-url"), body)
                    });
                }
            }
        }
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
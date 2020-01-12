var fn_src_base
var fn_rest_base

function FairyNodeExecute(page_name, src_base, rest_base) {

    $.getScript(src_base + "overview.js", function() {
        FairyNodeOverviewStart()
    });
    fn_src_base = src_base
    fn_rest_base = rest_base
}

function GetOrCreateDiv(id, parent_id, classes, cfg) {

    var $element = $('#' + id);
    if (!$element.length) {
        var element_type = "div"
        if (cfg != null) {
            if (cfg.type != null)
                element_type = cfg.type
            if (cfg.classes != null)
                classes = classes + " " + cfg.classes
        }
        $element = $('<' + element_type + ' id="' + id + '" class="' + classes + '"></' + element_type + '>').appendTo('#' + parent_id);
        if (cfg != null) {
            if (cfg.html != null) {
                $element.html(cfg.html)
            }
            if (cfg.data != null) {
                $element.attr("data", cfg.data)
            }
        }
    }

    return $element
}

function QueryGet(sub_url, on_data) {
    async function getData(url) {
        const response = await fetch(url, {
            method: 'GET', // *GET, POST, PUT, DELETE, etc.
            redirect: 'follow', // manual, *follow, error
        });
        return await response.json(); // parses JSON response into native JavaScript objects
    }

    getData(fn_rest_base + sub_url)
        .then((data) => {
            on_data(data); // JSON data parsed by `response.json()` call
        });
}

function QueryPost(sub_url, body, on_data) {
    console.log("POST " + sub_url + " " + JSON.stringify(body))
    async function getData(url) {
        const response = await fetch(url, {
            method: 'POST', // *GET, POST, PUT, DELETE, etc.
            redirect: 'follow', // manual, *follow, error
            body: JSON.stringify(body),
        });
        return await response.json(); // parses JSON response into native JavaScript objects
    }

    getData(fn_rest_base + sub_url)
        .then((data) => {
            if (on_data)
                on_data(data); // JSON data parsed by `response.json()` call
        });
}

function FormatSeconds(duration) {
    if (duration == null) {
        return "&lt;?&gt;"
    }

    var sec_num = parseInt(duration, 10); // don't forget the second param
    var hours = Math.floor(sec_num / 3600);
    var minutes = Math.floor((sec_num - (hours * 3600)) / 60);
    var seconds = sec_num - (hours * 3600) - (minutes * 60);
    var days = Math.floor(hours / 24);
    hours = hours - days * 24;

    if (hours < 10) { hours = "0" + hours; }
    if (minutes < 10) { minutes = "0" + minutes; }
    if (seconds < 10) { seconds = "0" + seconds; }
    // if (days < 10) { days = "0" + days; }

    return days + "d " + hours + ':' + minutes + ':' + seconds + "";
}
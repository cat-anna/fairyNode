function FairyNodeStart(src_base, rest_base, style, page_name) {
    function AddStyle(name) {
        var link = document.createElement("link");
        link.href = src_base + "style-" + name + ".css";
        link.type = "text/css";
        link.rel = "stylesheet";
        link.media = "screen,print";
        document.getElementsByTagName("head")[0].appendChild(link);
    }

    AddStyle(style);
    AddStyle("common");

    if (page_name == null) {
        page_name = "overview"
    }

    $.getScript(src_base + "Chart.bundle.min.js", function() {})
    $.getScript(src_base + "moment.min.js", function() {})
    $.getScript(src_base + "endpoint.js", function() {
        $.getScript(src_base + "common.js", function() {
            FairyNodeExecute(page_name, src_base, rest_base)
        });
    })
}

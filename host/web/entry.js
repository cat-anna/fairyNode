
function FairyNodeStart(base, style, page_name) {
    function AddStyle(name) {
        var link = document.createElement( "link" );
        link.href = base + "style-" + name + ".css";
        link.type = "text/css";
        link.rel = "stylesheet";
        link.media = "screen,print";
        document.getElementsByTagName( "head" )[0].appendChild( link );
    }

    AddStyle(style);
    AddStyle("common");

    if (page_name == null){
        page_name = "overview"
    }

    $.getScript(base + "common.js", function() {
        FairyNodeExecute(page_name, base)
    });    
}
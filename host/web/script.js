
function openTab(evt, tab_name) {
    // Declare all variables
    // var i, tabcontent, tablinks;

    // Get all elements with class="tabcontent" and hide them
    // tabcontent = document.getElementsByClassName("tabcontent");
    // for (i = 0; i < tabcontent.length; i++) {
    //   tabcontent[i].style.display = "none";
    // }

    // Get all elements with class="tablinks" and remove the class "active"
    // tablinks = document.getElementsByClassName("tablinks");
    // for (i = 0; i < tablinks.length; i++) {
    //   tablinks[i].className = tablinks[i].className.replace(" tab_active", " tab_inactive");
    // }

    $(".tab_active").removeClass("tab_active")
    $(".tabcontent").addClass("tab_inactive")
    $("#" + tab_name).addClass("tab_active").removeClass("tab_inactive")


    // Show the current tab, and add an "active" class to the link that opened the tab
    // document.getElementById(tab_name).style.display = "block";
    // evt.currentTarget.className += " tab_active";
}

function handleStateResponse(data) {
    // alert(data)
    console.log(data)
}

function refresh() {
    fetch('http://localhost:8000/device')
    // .then((resp) => resp.json()) 
    .then(function(data) {
        handleStateResponse(data)
      })
    .catch(function(error) {
    console.error(error)
      // If there is any error you will catch them here
    });   
}

function start() {
    // console.log("start")
    refresh()
    // setInterval(refresh, 5000);
}

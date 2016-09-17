var form = document.getElementById("uploadform");
var notice = document.getElementById("notice");
var points = document.getElementById("points");

// blocks the form while creating the package of corpus   
form.onsubmit = function(event) {
  if(!form.q.value) {
    event.preventDefault();
  } else {
    notice.style.display = "block";
    form.sub.disabled = "disabled";
  }
};

// shows the file downloader
setInterval(function() {
  if (Cookies.get("fileUploading")) {
    Cookies.remove("fileUploading");
    form.sub.disabled = "";
    notice.style.display = "none";
  }
}, 100);

// I don´t know
setInterval(function() {
  if(points.textContent.length >= 3) {
    points.textContent = "";
  } else {
    points.textContent += ".";
  }
}, 500);

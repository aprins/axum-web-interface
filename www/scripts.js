

var http_requests = [];
function ajax(url, func) {
  var i = 0;
  for(i=0; i<http_requests.length; i++)
    if(http_requests[i] == null)
      break;
  document.getElementById('loading').style.display = 'block';
  http_requests[i] = (window.ActiveXObject) ? new ActiveXObject('Microsoft.XMLHTTP') : new XMLHttpRequest();
  if(http_requests[i] == null) {
    alert("Your browse does not support the functionality this website requires.");
    return;
  }
  http_requests[i].onreadystatechange = function() {
    if(!http_requests[i] || http_requests[i].readyState != 4 || !http_requests[i].responseText)
      return;
    if(http_requests[i].status != 200)
      alert('Something seems to have gone wrong while saving the new configuration.');
    else
      func(http_requests[i]);
    http_requests[i] = null;
    for(i=0; i<http_requests.length; i++)
      if(http_requests[i] != null)
        break;
    if(i == http_requests.length)
      document.getElementById('loading').style.display = 'none';
  };
  url += (url.indexOf('?')>=0 ? ';' : '?')+(Math.floor(Math.random()*999)+1);
  http_requests[i].open('GET', url, true);
  http_requests[i].send(null);
}
function qq(v) {
  v = ''+v;
  return v.replace(/&/g,"&amp;").replace(/</,"&lt;").replace(/>/,"&gt;").replace(/"/g,'&quot;');
}



// creates an input container, positioned below obj
var input_obj = null;
function create_input(obj, submit) {
  if(input_obj != null && input_obj.obj == obj) {
    remove_input();
    return null;
  }
  remove_input();

  // get coordinates of obj (relative to our content div)
  var x = 0;
  var y = obj.offsetHeight;
  var c = document.getElementById('content');
  var o = obj;
  do {
    x += o.offsetLeft;
    y += o.offsetTop;
  } while((o = o.offsetParent) && o != c);

  // create input object
  input_obj = document.createElement('div');
  input_obj.style.position = 'absolute';
  input_obj.style.left = x+'px';
  input_obj.style.top = y+'px';
  input_obj.obj = obj;
  input_obj.id = 'input_obj';
  o.appendChild(input_obj);
  o = document.createElement('form');
  o.onsubmit = function() { submit(this); return false };
  input_obj.appendChild(o);
  return o;
}
function remove_input() {
  if(input_obj)
    document.getElementById('content').removeChild(input_obj);
  input_obj = null;
}
function click_input(e) {
  e = e || window.event;
  var tg = e.target || e.srcElement;
  while(tg && (tg.nodeType == 3 || tg.nodeName.toLowerCase() != 'div' || !tg.id || tg.id != 'input_obj'))
    tg = tg.parentNode;
  if(tg == null)
    remove_input();
  return true;
}


function conf_set(page, item, field, value, obj) {
  if(obj == null)
    obj = this;
  while(obj.nodeName.toLowerCase() != 'td')
    obj = obj.parentNode;
  ajax('/ajax/'+page+'?item='+item+';field='+field+';'+field+'='+encodeURIComponent(value), function(h) {
    obj.innerHTML = h.responseText;
    remove_input(input_obj);
  });
  return false;
}


function conf_level(page, item, field, value, obj) {
  var d = create_input(obj, function(f) {
    var val = f.getElementsByTagName('input')[0].value;
    if(isNaN(parseFloat(val)))
      return alert('Invalid number');
    conf_set(page, item, field, val, obj);
  });
  if(!d) return false;
  d.innerHTML = '<input type="text" value="'+qq(value)+'" size="6" class="text">dB '
    +'<input type="submit" value="Save" class="button">';
  d = d.getElementsByTagName('input')[0];
  d.focus();
  d.select();
  return false;
}


function conf_text(page, item, field, value, obj) {
  var d = create_input(obj, function(f) {
    conf_set(page, item, field, f.getElementsByTagName('input')[0].value, obj);
  });
  if(!d) return false;
  d.innerHTML = '<input type="text" value="'+qq(value)+'" size="10" class="text">'
    +'<input type="submit" value="Save" class="button">';
  d = d.getElementsByTagName('input')[0];
  d.focus();
  d.select();
  return false;
}


function conf_select(page, item, field, value, obj, list) {
  var d = create_input(obj, function(f) {
    var s = f.getElementsByTagName('select')[0];
    conf_set(page, item, field, s.options[s.selectedIndex].value, obj);
  });
  if(!d) return false;
  var r = '<select>';
  for(var i=0;i<list.length;i++)
    r += '<option value="'+qq(list[i][0])+'"'+(list[i][0] == value ? ' selected="selected"':'')+'>'+qq(list[i][1])+'</option>';
  r += '</select><input type="submit" value="Save" class="button">';
  d.innerHTML = r;
  d.getElementsByTagName('select')[0].focus();
  return false;
}


function exp_over() {
  var el = this.abbr ? this : document.getElementById(this.className);
  if(el.over)
    return;
  el.over = 1;
  var tmp;
  tmp = el.abbr;
  el.abbr = el.innerHTML;
  el.innerHTML = tmp;
}
function exp_out() {
  var el = this.abbr ? this : document.getElementById(this.className);
  tmp = el.abbr;
  el.abbr = el.innerHTML;
  el.innerHTML = tmp;
  el.over = 0;
}


window.onmousedown = click_input;

window.onload = function() {
  // look for all td/th tags with a class starting with exp_
  var i;
  var l = document.getElementsByTagName('td');
  for(i=0; i<l.length; i++)
    if(l[i].className.indexOf('exp_') == 0 || l[i].id.indexOf('exp_') == 0) {
      l[i].onmouseover = exp_over;
      l[i].onmouseout = exp_out;
    }
  l = document.getElementsByTagName('th');
  for(i=0; i<l.length; i++)
    if(l[i].className.indexOf('exp_') == 0 || l[i].id.indexOf('exp_') == 0) {
      l[i].onmouseover = exp_over;
      l[i].onmouseout = exp_out;
    }
};



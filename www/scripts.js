

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
function create_input(obj, submit, offheight, offwidth) {
  if(input_obj != null && input_obj.obj == obj) {
    remove_input();
    return null;
  }
  remove_input();

  // get coordinates of obj (relative to our content div)
  var x = offwidth == null ? 0 : offwidth;
  var y = offheight == null ? obj.offsetHeight : offheight;
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
  o.method = 'POST';
  o.onsubmit = submit == null ? null : function() { submit(this); return false };
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


function conf_number(unit, page, item, field, value, obj) {
  var d = create_input(obj, function(f) {
    var val = f.getElementsByTagName('input')[0].value;
    if(isNaN(parseFloat(val)))
      return alert('Invalid number');
    conf_set(page, item, field, val, obj);
  });
  if(!d) return false;
  d.innerHTML = '<input type="text" value="'+qq(value)+'" size="6" class="text">'+unit
    +' <input type="submit" value="Save" class="button" />';
  d = d.getElementsByTagName('input')[0];
  d.focus();
  d.select();
  return false;
}


function conf_level(page, item, field, value, obj) { return conf_number('dB', page, item, field, value, obj); }
function conf_freq( page, item, field, value, obj) { return conf_number('Hz', page, item, field, value, obj); }
function conf_proc( page, item, field, value, obj) { return conf_number('%',  page, item, field, value, obj); }


function conf_text(page, item, field, value, obj) {
  var d = create_input(obj, function(f) {
    conf_set(page, item, field, f.getElementsByTagName('input')[0].value, obj);
  });
  if(!d) return false;
  var size = value.length > 10 ? value.length+5 : 10;
  d.innerHTML = '<input type="text" value="'+qq(value)+'" size="'+size+'" class="text">'
    +'<input type="submit" value="Save" class="button" />';
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
  d.innerHTML = document.getElementById(list).innerHTML
    +'<input type="submit" value="Save" class="button" />';
  d = d.getElementsByTagName('select')[0];
  d.style.display = 'inline';
  for(var i=0; i<d.length; i++)
    if(d.options[i].value == value)
      d.options[i].selected = true;
  d.focus();
  return false;
}


/* this is an actual form, doesn't use AJAX */
function conf_addsrcdest(obj, list, type) {
  var d = create_input(obj, null, -70);
  if(!d) return false;

  var uctype = type.substr(0,1).toUpperCase() + type.substr(1,type.length);
  d.style.textAlign = 'right';
  d.innerHTML =
    '<label for="'+type+'1" >'+uctype+' 1 (left):</label>'+document.getElementById(list).innerHTML+'<br />'
   +'<label for="'+type+'2">'+uctype+' 2 (right):</label>'+document.getElementById(list).innerHTML+'<br />'
   +'<label for="label">Label:</label><input type="text" class="text" name="label" id="label" size="10" />'
   +' <input type="submit" value="Create" class="button" />';
  d = d.getElementsByTagName('select');
  d[0].name = d[0].id = type+'1';
  d[1].name = d[1].id = type+'2';
  d[0].style.width = d[1].style.width = '350px';
  return false;
}


function conf_eq(obj, item) {
  var d = create_input(obj, function (o) {
    var val = '';
    var l = o.getElementsByTagName('input');
    for(var i=0; i<l.length; i++)
      if(l[i].name)
        val += ';'+l[i].name+'='+encodeURIComponent(l[i].value);
    l = o.getElementsByTagName('select');
    for(i=0; i<l.length; i++)
      val += ';'+l[i].name+'='+encodeURIComponent(l[i].options[l[i].selectedIndex].value);
    val = val.substr(1, val.length-1);
    ajax('/ajax/module/'+item+'/eq?'+val, function(h) {
      document.getElementById('eq_table_container').innerHTML = h.responseText;
      remove_input(input_obj);
    });
  }, 0, obj.offsetWidth);
  if(!d) return false;
  d.innerHTML = document.getElementById('eq_table_container').innerHTML;
  d.getElementsByTagName('table')[0].id = 'eq_table';
  return false;
}


function conf_func(addr, nr, f1, f2, f3, sensor, actuator, obj) {
  var i;var l;var o;
  var d = create_input(obj, function(f) {
    l = document.getElementById('func_main').getElementsByTagName('select')[0];
    f1 = l.options[l.selectedIndex].value;
    l = document.getElementById('func_'+f1);
    if(!l) {
      f2 = f3 = 0;
    } else {
      l = l.getElementsByTagName('select');
      f2 = f1 == 4 ? 0 : l[0].options[l[0].selectedIndex].value;
      f3 = l[f1==4?0:1].options[l[f1==4?0:1].selectedIndex].value;
    }
    while(obj.nodeName.toLowerCase() != 'td')
      obj = obj.parentNode;
    ajax('/ajax/setfunc?addr='+addr+';nr='+nr
        +';function='+f1+','+f2+','+f3+';sensor='+sensor+';actuator='+actuator, function(h) {
      obj.innerHTML = h.responseText;
      remove_input(input_obj);
    });
  });
  if(!d) return false;
  d.innerHTML = 'loading function list...';
  ajax('/ajax/func?sensor='+sensor+';actuator='+actuator, function(h) {
    d.innerHTML = h.responseText + '<input type="submit" value="Save" class="button" />';
    l = d.getElementsByTagName('div');
    for(i=0; i<l.length; i++)
      if(l[i].id != 'func_main' && l[i].id != 'func_'+f1)
        l[i].className = 'hidden';
    l = document.getElementById('func_main').getElementsByTagName('select')[0];
    for(i=0; i<l.options.length; i++)
      l.options[i].selected = l.options[i].value == f1;
    l.onchange = function() {
      f1 = this.options[this.selectedIndex].value;
      l = d.getElementsByTagName('div');
      for(i=0; i<l.length; i++)
        l[i].className = l[i].id != 'func_main' && l[i].id != 'func_'+f1 ? 'hidden' : '';
    };
    l = document.getElementById('func_'+f1);
    if(l) {
      l = l.getElementsByTagName('select');
      o = f1 == 4 ? l[0] : l[1];
      for(i=0; i<o.options.length; i++)
        o.options[i].selected = o[i].value == f3;
      if(f1 != 4)
        for(i=0,o=l[0].options; i<o.length; i++)
          o[i].selected = o[i].value == f2;
    }
  });
  return false;
}

function conf_id(addr, man_id, prod_id, firm_major, obj) {
  var selected_id, l, i;
  var d = create_input(obj, function(f) {
    l = document.getElementById('id_main').getElementsByTagName('select')[0];
    selected_id = l.options[l.selectedIndex].value;
    while(obj.nodeName.toLowerCase() != 'td')
      obj = obj.parentNode;
    alert('/ajax/change_conf?addr='+addr+';man='+man_id+';prod='+prod_id+';id='+selected_id+';firm_major='+firm_major);
    ajax('/ajax/change_conf?addr='+addr+';man='+man_id
        +';prod='+prod_id+';id='+selected_id+';firm_major='+firm_major, function(h) {
      obj.innerHTML = h.responseText;
      remove_input(input_obj);
      location.reload(true);
    });
  });
  if(!d) return false;
  d.innerHTML = 'loading id list...';
  ajax('/ajax/id_list?man='+man_id+';prod='+prod_id+';firm_major='+firm_major, function(h) {
    d.innerHTML = h.responseText + '<input type="submit" value="Save" class="button" />';
    l = d.getElementsByTagName('div');
    l = document.getElementById('id_main').getElementsByTagName('select')[0];
    for(i=0; i<l.options.length; i++)
      l.options[i].selected = l.options[i].value == selected_id;
  });
  return false;
}

function exp_over() {
  var str_array = this.className.split(' ');
  var el = this.abbr ? this : document.getElementById(str_array[0]);
  if(el.over)
    return;
  el.over = 1;
  var tmp;
  tmp = el.abbr;
  el.abbr = el.innerHTML;
  el.innerHTML = tmp;
}
function exp_out() {
  var str_array = this.className.split(' ');
  var el = this.abbr ? this : document.getElementById(str_array[0]);
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



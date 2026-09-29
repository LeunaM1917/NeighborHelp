(function () {
  var key = 'AIzaSyAyVtgM4krujoTikVPVHIw3riokT_ngwps';
  if (!key) return;
  var s = document.createElement('script');
  s.async = true;
  s.defer = true;
  s.src = 'https://maps.googleapis.com/maps/api/js?key=' + encodeURIComponent(key);
  document.head.appendChild(s);
})();
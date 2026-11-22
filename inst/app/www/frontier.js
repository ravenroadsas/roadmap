/* Frontier view: a click on a point or a row sets the selected combination. */
document.addEventListener('click', function (ev) {
  var t = ev.target.closest && ev.target.closest('.fr-root [data-pick]');
  if (!t || !window.Shiny) return;
  var box = t.closest('[data-input]');
  Shiny.setInputValue(box.dataset.input, t.dataset.pick, { priority: 'event' });
});

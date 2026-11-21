window.addEventListener('keydown', e => {
  if (e.which !== 32 || ['TEXTAREA', 'INPUT'].includes(e.target.nodeName)) return;

  flipbuttons.func();
  e.preventDefault();
});

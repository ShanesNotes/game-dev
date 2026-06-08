// Shared lesson interactivity: quiz feedback + code copy buttons.
function pick(btn){
  const q = btn.closest('.quiz');
  if (q.dataset.done) return;
  const fb = q.querySelector('.feedback');
  if (btn.hasAttribute('data-correct')){
    btn.classList.add('right'); q.dataset.done = '1';
    fb.textContent = '✓ CORRECT'; fb.style.color = '#5fd38a';
  } else {
    btn.classList.add('wrong');
    fb.textContent = '✗ not quite — try again'; fb.style.color = '#ff6b6b';
  }
}
document.addEventListener('click', e => {
  const b = e.target.closest('.code .copy'); if (!b) return;
  const code = b.closest('.code').querySelector('pre');
  navigator.clipboard.writeText(code.innerText).then(() => {
    const old = b.textContent; b.textContent = 'copied ✓'; b.classList.add('done');
    setTimeout(() => { b.textContent = old; b.classList.remove('done'); }, 1400);
  });
});

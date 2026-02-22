(function () {
  const toggle = document.querySelector('.menu-toggle');
  const nav = document.querySelector('.site-nav');
  if (!toggle || !nav) return;

  toggle.addEventListener('click', function () {
    const isOpen = nav.classList.toggle('is-open');
    toggle.classList.toggle('is-active', isOpen);
    toggle.setAttribute('aria-expanded', isOpen);
  });

  document.addEventListener('click', function (e) {
    if (!nav.contains(e.target) && !toggle.contains(e.target) && nav.classList.contains('is-open')) {
      nav.classList.remove('is-open');
      toggle.classList.remove('is-active');
      toggle.setAttribute('aria-expanded', 'false');
    }
  });

  // "More" menu toggle
  const moreBtn = document.querySelector('.site-nav__more-btn');
  if (moreBtn) {
    moreBtn.addEventListener('click', function () {
      document.querySelectorAll('.site-nav__item--more').forEach(function (item) {
        item.classList.toggle('is-visible');
      });
    });
  }
})();

(function() {
  // Get theme from localStorage or default to dark
  const currentTheme = localStorage.getItem('theme') || 'dark';
  
  // Apply theme immediately (before DOM is ready to prevent flash)
  if (currentTheme === 'light') {
    document.documentElement.setAttribute('data-theme', 'light');
  } else {
    document.documentElement.removeAttribute('data-theme');
  }
  
  // Apply theme function
  function setTheme(theme) {
    if (theme === 'light') {
      document.documentElement.setAttribute('data-theme', 'light');
    } else {
      document.documentElement.removeAttribute('data-theme');
    }
    localStorage.setItem('theme', theme);
    updateThemeSwitcher(theme);
  }
  
  // Update theme switcher active state
  function updateThemeSwitcher(theme) {
    const darkLink = document.getElementById('theme-dark');
    const lightLink = document.getElementById('theme-light');
    
    if (darkLink && lightLink) {
      if (theme === 'dark') {
        darkLink.classList.add('active');
        lightLink.classList.remove('active');
      } else {
        lightLink.classList.add('active');
        darkLink.classList.remove('active');
      }
    }
  }
  
  // Handle theme switcher clicks
  document.addEventListener('DOMContentLoaded', function() {
    // Update switcher state on load
    updateThemeSwitcher(currentTheme);
    
    const darkLink = document.getElementById('theme-dark');
    const lightLink = document.getElementById('theme-light');
    
    if (darkLink) {
      darkLink.addEventListener('click', function(e) {
        e.preventDefault();
        setTheme('dark');
      });
    }
    
    if (lightLink) {
      lightLink.addEventListener('click', function(e) {
        e.preventDefault();
        setTheme('light');
      });
    }
  });
})();


// Initialize AOS Animation Library
AOS.init({
    duration: 1000,
    once: true,
    offset: 100
});

// Mobile Menu Toggle
const menuToggle = document.querySelector('.menu-toggle');
const navLinks = document.querySelector('.nav-links');

if (menuToggle) {
    menuToggle.addEventListener('click', () => {
        navLinks.classList.toggle('active');
    });
}

// Hero Text Rotation (Re-enabled with new content)
const heroContent = [
    {
        h1: 'The Next Evolution of <br> <span class="gradient-text">Smart Invoicing</span>',
        p: 'Experience a billing platform designed for the future. 3D analytics, real-time inventory, and bank-grade security in one immersive workspace.'
    },
    {
        h1: 'Real-Time Inventory <br> <span class="gradient-text">Management</span>',
        p: 'Never run out of stock again. Track every item in real-time with low-stock alerts and expiration tracking.'
    },
    {
        h1: 'Comprehensive Expense <br> <span class="gradient-text">Tracking</span>',
        p: 'Keep a pulse on your business spending. Categorize expenses and visualize where every penny goes instantly.'
    },
    {
        h1: 'Instant GST Quotes & <br> <span class="gradient-text">Invoices</span>',
        p: 'Create professional, tax-compliant invoices and quotes in seconds. Share directly via WhatsApp.'
    },
    {
        h1: 'Actionable Business <br> <span class="gradient-text">Insights</span>',
        p: 'Turn data into decisions with powerful 3D visualization reports and automated P&L statements.'
    }
];

let currentSlide = 0;
const heroTitle = document.getElementById('hero-title');
const heroSubtitle = document.getElementById('hero-subtitle');

if (heroTitle && heroSubtitle) {
    // Add initial transition styles via JS class if not present
    heroTitle.style.transition = 'opacity 0.5s ease-in-out, transform 0.5s ease-in-out';
    heroSubtitle.style.transition = 'opacity 0.5s ease-in-out, transform 0.5s ease-in-out';

    setInterval(() => {
        // 1. Fade Out
        heroTitle.style.opacity = '0';
        heroTitle.style.transform = 'translateY(-10px)';
        heroSubtitle.style.opacity = '0';
        heroSubtitle.style.transform = 'translateY(-10px)';

        // 2. Wait for fade out, then swap text
        setTimeout(() => {
            currentSlide = (currentSlide + 1) % heroContent.length;

            heroTitle.innerHTML = heroContent[currentSlide].h1;
            heroSubtitle.textContent = heroContent[currentSlide].p;

            // 3. Fade In
            heroTitle.style.opacity = '1';
            heroTitle.style.transform = 'translateY(0)';
            heroSubtitle.style.opacity = '1';
            heroSubtitle.style.transform = 'translateY(0)';
        }, 500); // Wait 500ms for fade out

    }, 4000); // Change every 4 seconds
}

// Close Mobile Menu on Link Click
document.querySelectorAll('.nav-links a').forEach(link => {
    link.addEventListener('click', () => {
        navLinks.classList.remove('active');
    });
});

// Smooth Scrolling for Anchor Links (Backup for older browsers)
document.querySelectorAll('a[href^="#"]').forEach(anchor => {
    anchor.addEventListener('click', function (e) {
        e.preventDefault();

        document.querySelector(this.getAttribute('href')).scrollIntoView({
            behavior: 'smooth'
        });
    });
});

// Navbar Scroll Effect
window.addEventListener('scroll', () => {
    const navbar = document.querySelector('.navbar');
    if (window.scrollY > 50) {
        navbar.style.boxShadow = "0 4px 6px -1px rgba(0, 0, 0, 0.1)";
        navbar.style.padding = "10px 0";
    } else {
        navbar.style.boxShadow = "none";
        navbar.style.padding = "15px 0";
    }
});

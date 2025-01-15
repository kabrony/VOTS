// capture_dashboard.js
const puppeteer = require('puppeteer');

(async () => {
  try {
    // 1) Launch headless Chrome
    const browser = await puppeteer.launch();
    const page = await browser.newPage();

    // 2) Navigate to your Next.js dashboard URL
    //    Adjust the URL to match your local or Docker environment
    await page.goto('http://localhost:3000/dashboard', {
      waitUntil: 'networkidle2',
    });

    // 3) Optional: set viewport size
    await page.setViewport({ width: 1280, height: 800 });

    // 4) Screenshot
    await page.screenshot({ path: 'dashboard_screenshot.png', fullPage: true });
    console.log('Screenshot saved as dashboard_screenshot.png');

    // 5) Close
    await browser.close();
  } catch (err) {
    console.error('Error capturing screenshot:', err);
    process.exit(1);
  }
})();

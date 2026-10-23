# Saurdev Shrestha · portfolio

A static, single-page portfolio: **Tech**, **Works** and **People & care** views, a contact form, and an image viewer. No build step and no server code; the whole site is `index.html` plus anything in `images/`.

## Put it on the droplet (one time)

Run these on the droplet (DigitalOcean → your droplet → **Console**), replacing `yourdomain.com`:

```bash
sudo git clone https://github.com/SaurdevSth/pwbs.git /var/www/saurdev-portfolio
sudo bash /var/www/saurdev-portfolio/deploy/setup.sh yourdomain.com
```

The script adds a new site for that domain on whichever web server is running (Nginx or Apache) and leaves any existing sites alone. If the domain is already used by another site, it stops without changing anything.

Then point the domain at the droplet (an `A` record for `@` and for `www` with the droplet's IP), and turn on HTTPS with the `certbot` command the script prints.

## Updating

The droplet pulls this repository every 5 minutes, so anything pushed to `main` goes live on its own.

- **Images:** put screenshots and photos in `images/` and reference them by file name in the site data inside `index.html`.
- **Contact form:** set `FORM_ENDPOINT` near the top of the main script in `index.html` to your form service URL (for example Formspree).

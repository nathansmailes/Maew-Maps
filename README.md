# Maew Maps

A map of Bangkok where neighbours pin the street cats they spot. Each cat gets a profile: a friendliness rating, name votes, a description so nobody adds the same cat twice, and comments in Thai or English.

**Try it:** https://nathansmailes.github.io/maew-maps/

## How it works right now

- One file, `index.html`. Open it in any browser.
- The map uses Leaflet with OpenStreetMap data (CARTO tiles).
- Cats are saved in your own browser only, so other people don't see them yet. A shared database is the next step.
- Cats that nobody has seen for a year are removed automatically.

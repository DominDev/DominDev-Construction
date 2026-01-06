/**
 * Generate srcset images for responsive loading
 * Requires: npm install sharp
 * Run: node _scripts/generate-srcset.js
 */

const sharp = require('sharp');
const fs = require('fs');
const path = require('path');

const SIZES = [400, 800];
const INPUT_DIR = path.join(__dirname, '..', 'assets', 'images');

// Find all source PNG files (dach-* and hero-building-*)
const files = fs.readdirSync(INPUT_DIR).filter(f =>
    (f.startsWith('dach-') || f.startsWith('hero-building-')) &&
    f.endsWith('.png') &&
    !f.includes('-400w') &&
    !f.includes('-800w') &&
    !f.includes('-1200w')
);

console.log(`Found ${files.length} source images to process:`);
files.forEach(f => console.log(`  - ${f}`));
console.log('');

let processed = 0;
const totalOperations = files.length * SIZES.length * 2; // 2 formats per size

files.forEach(file => {
    const base = path.basename(file, '.png');
    const inputPath = path.join(INPUT_DIR, file);

    SIZES.forEach(size => {
        // Generate WebP
        const webpOutput = path.join(INPUT_DIR, `${base}-${size}w.webp`);
        sharp(inputPath)
            .resize(size)
            .webp({ quality: 85 })
            .toFile(webpOutput)
            .then(() => {
                processed++;
                console.log(`✓ Created: ${base}-${size}w.webp`);
                if (processed === totalOperations) {
                    console.log(`\n✅ All ${totalOperations} images generated successfully!`);
                }
            })
            .catch(err => console.error(`✗ Error creating ${base}-${size}w.webp:`, err.message));

        // Generate PNG
        const pngOutput = path.join(INPUT_DIR, `${base}-${size}w.png`);
        sharp(inputPath)
            .resize(size)
            .png({ quality: 85, compressionLevel: 9 })
            .toFile(pngOutput)
            .then(() => {
                processed++;
                console.log(`✓ Created: ${base}-${size}w.png`);
                if (processed === totalOperations) {
                    console.log(`\n✅ All ${totalOperations} images generated successfully!`);
                }
            })
            .catch(err => console.error(`✗ Error creating ${base}-${size}w.png:`, err.message));
    });
});

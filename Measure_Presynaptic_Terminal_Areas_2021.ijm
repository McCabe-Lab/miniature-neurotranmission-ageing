/*
 * Measurements of HB9 presynaptic terminal area during ageing
 * 
 * This macro expects a single channel image of HB9 terminals.
 * 
 * It will measure an area based on auto-thresholding on the HB9 channel which will have been
 * - Background subtracted to remove low frequency local structures
 * - Smoothed with a 3x3 gaussian kernel
 * - Intensity variations dampened by means of applying a square root. 
 * 
 * This works under the assumptions that the background does not change between conditions
 * and that the changes in area are not expected to be major (less than 3x fold change). Otherwise another measure might be necessary
 * 
 * Careful with absolute area measurements. Area ratios, with respect to 
 * a known measurable structure is usually much more informative.
 * 
 * OUTPUT:
 * A results table with the area of all particles above 0.4 um^2 on the image
 * 
 * Code by Olivier Burri, EPFL - SV - PTECH - BIOP
 * For Dr. Soumya Banerjee, EPFL - SV - UPMCCABE
 * 
 * Last modified: 07.06.2021
 * 
 */

// Choose auto threshold method
threshold="Li";
//threshold="Yen"; // previous run

run("Set Measurements...", "area mean standard area_fraction centroid center perimeter fit integrated limit display redirect=None decimal=3");
run("Duplicate...", " ");
run("Subtract Background...", "rolling=20");
run("Smooth");
//run("Gaussian Blur...", "sigma=1.0");
run("32-bit");
run("Square Root");
run("Enhance Contrast", "saturated=0.35");
setAutoThreshold(threshold+" dark");
run("Analyze Particles...", "size=0.4-Infinity show=Masks summarize");

/* 
 * Macro for folder processing of confocal images consisting of: 
 * - Green: HB9 presynaptic terminals
 * - Red: Active Zones
 * - Blue: Anti-vGlut staining
 * 
 * 
 * 
 * In short this macro
 * - Segments the active zones as single points using a lacal maximum finder on the red channel
 * - Segments the HB9 and vGlut channels using a threshold to localize the regions of interest
 * - Counts the number of active zones inside the regions of interest
 * 
 * Output:
 * - A results table with one row per image and the count of AZs in each zone.
 * 
 * Requirements: 
 * - PTBIOP Update Site https://imagej.net/update-sites/followinghttps://imagej.net/update-sites/following
 * 
 * Code by Olivier Burri, EPFL - SV - PTECH - BIOP
 * For Dr. Soumya Banerjee, EPFL - SV - UPMCCABE
 * 
 * Last modified: 07.06.2021
 */

// Install the BIOP Library (from PTBIOP update site)

call("BIOP_LibInstaller.installLibrary", "BIOP"+File.separator+"BIOPLib.ijm");
//run("Close All");
run("Clear Results");
roiManager("Reset");
	run("Set Measurements...", "area integrated display redirect=None decimal=3");
	setOption("BlackBackground", true);

// If you remove the comments from these two lines it runs on the current image
processImage();
exit;

//get directory 
imageFolder = getImageFolder();
saveFolder = getSaveFolder();
imageNumber = getNumberImages();


setBatchMode(true);
for (imageIndex = 0 ; imageIndex < imageNumber ; imageIndex++){
	roiManager("Reset");
	openImage(imageIndex);					// open the image (an its assiciated roiset.zip)
	processImage();							// process the image
	saveRois("Save");						// save the ROIset with the current image
	saveCurrentImage();						// save the current image
	run("Close All");						// close all
}

if( isOpen("Results") ){
	selectWindow("Results");
	saveAs("Results", saveFolder+"results.txt");// save the results
}

setBatchMode(false);

showMessage("Jobs DONE!");



// required functions 

function toolName() {
	return "Soumya Macro";
}

function processImage(){
	
	greenBlur = 1;
	 greenThr = "Triangle";
	
	blueBlur = 1;
	 blueThr = "Triangle";
	
	redBGSize = 4;
	redNoise = 80;


	shrink_by=0;
	
	ori = getTitle();
	

	// Get Red Points
	selectImage(ori);
	setSlice(3);
	run("Duplicate...", "title=["+ori+" Red]");
	run("Subtract Background...", "rolling="+redBGSize+" slice");
	run("Enhance Contrast", "saturated=0.35");
	run("Find Maxima...", "noise="+redNoise+" output=[Point Selection]");
	Roi.setName("Points");
	roiManager("Add");
	getSelectionCoordinates(px,py);


	
	// Get Green Mask
	selectImage(ori);
	setSlice(1);
	run("Duplicate...", "title=["+ori+" Green]");
	
	run("Gaussian Blur...", "sigma="+greenBlur);
	setAutoThreshold(greenThr+" dark");
	run("Convert to Mask");
	run("Create Selection");
	
	run("Enlarge...", "enlarge="+shrink_by+" pixel");
	Roi.setName("Green Mask");
	roiManager("Add");
	//Keep Spots Inside
	gx = newArray(0);
	gy = newArray(0);
	for(i=0;i<px.length;i++) {
		if(Roi.contains(px[i],py[i])) {
			gx = Array.concat(gx,px[i]);
			gy = Array.concat(gy,py[i]);
		}

	}
	makeSelection("point", gx,gy);
	Roi.setName("Points In Green");
	roiManager("Add");
	
	
	// Get Blue Mask
	selectImage(ori);
	setSlice(2);
	run("Duplicate...", "title=["+ori+" Blue]");
	run("Gaussian Blur...", "sigma="+blueBlur);
	setAutoThreshold(blueThr+" dark");
	run("Convert to Mask");
	run("Create Selection");
	run("Enlarge...", "enlarge="+shrink_by+" pixel");
	Roi.setName("Blue Mask");
	roiManager("Add");
	//Keep Spots Inside
	bx = newArray(0);
	by = newArray(0);
	for(i=0;i<px.length;i++) {
		if(Roi.contains(px[i],py[i])) {
			bx = Array.concat(bx,px[i]);
			by = Array.concat(by,py[i]);
		}
	}
	makeSelection("point", bx,by);
	Roi.setName("Points In Blue");
	roiManager("Add");
	
	// Make point image
	getDimensions(x,y,c,z,t);
	getVoxelSize(vx,vy,vz,U);
	newImage(ori+" Points", "8-bit black", x, y, 1);
	setVoxelSize(vx,vy,vz,U);
	roiManager("Select", 0);
	setForegroundColor(1, 1, 1);
	run("Draw", "slice");
	
	// Make the AND Mask
	roiManager("Select", newArray(0,1));
	roiManager("AND");
	Roi.setName("Both");
	roiManager("Add");
	
	run("Set Measurements...", "area integrated display redirect=None decimal=3");
	// Measure
	run("Select None");
	run("Measure");
	roiManager("Select",1);
	run("Measure");
	roiManager("Select",3);
	run("Measure");
	roiManager("Select",5);
	run("Measure");
	run("Select None");
	run("Maximum...", "radius=2");

	// Red Intensities
	
	selectImage(ori);
	setSlice(3);
	run("Duplicate...", "title=["+ori+" Red Ints]");
	run("Gaussian Blur...", "sigma=2");
	roiManager("Select",2);
	prepareTable("Spots Intensities");
	run("Set Measurements...", "mean display redirect=None decimal=3");
	run("Measure");
	roiManager("Select",4);
	run("Measure");
	closeTable("Spots Intensities");
	
	run("Merge Channels...", "c1=["+ori+" Green] c2=["+ori+" Blue] c3=["+ori+" Points] create keep");
	selectImage("Composite");
	rename(ori+" - Masks");
	setSlice(3);
	run("Multiply...", "value=255 slice");
	run("biop-Amber");
	setSlice(2);
	run("biop-ElectricIndigo");
	setSlice(1);
	run("biop-SpringGreen");
	
}




/**
 * Detect Surfaces and Spots in Imaris using EasyXT
 * Filter spots wether they are inside the surface or not
 * Export the volumes of the spots as results
 * NOTE: This has been optimized on deconvolved images and may not be as accurate on raw data
 * 
 * Requirements
 * ------------
 * The following update sites need to be enabled
 * 1. EasyXT-Fiji, https://biop.epfl.ch/Fiji-EasyXT/
 * 2. 3D ImageJ Suite
 * 
 * A Working Imaris Instance running version 9.5 (or above) is required
 * with a valid XTensions license
 * 
 * Imaris should be open before starting this code. 
 * BUG: Make sure that Imaris is open AND that a dataset is loaded before starting. 
 * It is a known issue that opening an image from EasyXT on a fresh Imaris can cause a crash.
 * 
 * Author: Olivier Burri, EPFL - SV - PTECH - BIOP
 * For: Dr. Soumya Banerjee, EPFL - SV - UPMCCABE
 * February 4th 2021
 * 
 * Last modified: June 7th 2021
 */

#@File image
EasyXT.Files.openImage(image)

def image = EasyXT.Files.getOpenFile()

def channelBoutons = 1
boutonsThreshold = 50

def channelSAZ = 2
def azQuality = 50
def azThreshold = 0.6

// Detect the surface
def surf = EasyXT.Surfaces.create( channelBoutons-1 )
        .setSmoothingWidth( 0.3 )
        .setLocalContrastFilterWidth( 4 ) // Local contrast but keep large objects
        .setSurfaceFilter( "\"Volume\" between 1.00 um^3 and 3000 um^3" )
        .setLowerThreshold( boutonsThreshold )
        .setName( "Boutons of Interest" )
        .build().detect()

// Add surfaces to the scene
EasyXT.Scene.addItem(surf)

// Detect the Spots

def spots = EasyXT.Spots.create( channelSAZ-1 )
        .setDiameterXYZ( 0.310, 0.620 )
        .isRegionsFromLocalContrast( true )
        .isSubtractBackground( true )
        .setFilter( "\"Quality\" above "+ azQuality )
        .isRegionsSpotsDiameterFromVolume( false )
        .isCreateRegionsChannel( false )
        .setRegionsThresholdManual( azThreshold )
        .setName( "Active Zones" )
        .build().detect()

/*
// Detect the With Intensity
def spots = EasyXT.Spots.create( channelSAZ-1 )
        .setDiameterXYZ( 0.310, 0.620 )
        .isRegionsFromLocalContrast( false )
        .isSubtractBackground( true )
        .setFilter( "\"Quality\" above "+ azQuality )
        .isRegionsSpotsDiameterFromVolume( true )
        .isCreateRegionsChannel( false )
        .setRegionsThresholdManual( 100 )
        .setName( "Active Zones" )
        .build().detect()
*/

// Add Spots to the scene
EasyXT.Scene.addItem(spots)
// We neededn't add them unless we're debugging. We just want the spots inside the surface in the end

// Get the surface as an ImageJ mask
surf_imp = EasyXT.Surfaces.getMaskImage(surf);

// Get Spots Coordinates to find which are inside the mask

// We will use the wonderful library made by Thomas Boudier, mcib3d
// This will allow us to query voxel values at arbitrary coordinates
ImageByte surf_ib = new ImageByte(surf_imp);

// Pick up all spots information for filtering and re-inserting into the scene afterwards
def pos = spots.GetPositionsXYZ();
def radii = spots.GetRadiiXYZ();
def times = spots.GetIndicesT();


// Use the calibration to convert from real coordinates to pixel coordinates
def cal = surf_ib.getCalibration();

// Need to build multiple objects
// the list of points and their associated radii and timepoints
def points = [pos, radii, times].transpose().collect { p, r, t ->
    // Get spot coordinates in pixels
    pointpx = new Point3D( cal.getRawX( p[0] ), cal.getRawY( p[1] ), cal.getRawZ( p[2] ) )

    // Get spots coordinates in calibrated units
    point = new Point3D( p[0], p[1], p[2] )

    // Get radii 
    r2 = new Point3D(r[0], r[1], r[2])

    // Return a map that contains everything at the right position, even though we do not need the IDs
    return  [point: point, pointpx: pointpx, radii: r2, time:t ]
}

// Find any points inside the surface mask, that is, wher eteh voxel value is not zero
inPoints = points.findAll{p->
	// Let it pick up the interpolated pixel value at the given location
	val =  surf_ib.getPixelInterpolated( p.pointpx )
	
	return val > 0
}

// Close to save some RAM
surf_ib.closeImagePlus()

// Recreate points inside as a new object in Imaris by collecting them into their indovidual lists again
def coordinates = inPoints.collect{ it.point }
def rad = inPoints.collect{ it.radii }
def t = inPoints.collect{ it.time }

// And calling EasyXT to create the spots with these lists
inSpots = EasyXT.Spots.create( coordinates, rad, t )
EasyXT.Scene.setName( inSpots, "Active Zones Inside" )
EasyXT.Scene.addItem( inSpots )

// If the results table exists, use it
def results = ResultsTable.getResultsTable( "In Bouton AZ Statistics" ) == null ? new ResultsTable() : ResultsTable.getResultsTable( "In Bouton AZ Statistics" )

// Get the volume and the max intensity of the spot objects
def stats = new StatsQuery( inSpots )
				.selectStatistics( ["Volume", "Intensity Max"] )
				.resultsTable( results ).get()

stats.show( "In Bouton AZ Statistics" );

// If the results table exists, use it
def resultsAll = ResultsTable.getResultsTable( "All AZ Statistics" ) == null ? new ResultsTable() : ResultsTable.getResultsTable( "All AZ Statistics" )

// Get the volume and the max intensity of all of the the spot objects 
def statsAll = new StatsQuery( spots )
				.selectStatistics( ["Volume", "Intensity Max"] )
				.resultsTable( resultsAll ).get()

statsAll.show( "All AZ Statistics" );

// Resave IMS file

def saveDirectory = new File( image.getParent(), "Processed" )
saveDirectory.mkdirs()

def saveFile =  new File ( saveDirectory, image.getName() + ".ims" )

EasyXT.Files.saveImage( saveFile )

// Imports
import ch.epfl.biop.imaris.EasyXT
import ch.epfl.biop.imaris.StatsQuery
import mcib3d.geom.Point3D
import mcib3d.image3d.ImageByte
import ij.IJ
import ij.measure.ResultsTable
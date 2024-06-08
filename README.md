# Image Classification and Worm Detection
This work has two main objectives: first, it seeks to develop a program that, given a microscope image in which a certain number of worms appear, is able to classify the image according to whether the majority of worms are alive or dead.  At the same time, it is also sought to make a count of the total worms that appear in the image, determining for each one whether it is alive or dead.

## Requirements and Execution
This project has a really simple environment, as it uses only tools from the MatLab suite. The requirements are the following:
- MATLAB vR2023a
- MATLAB Image Processing Toolbox
Having this installed, you can run the code from MATLAB's command line calling the main function ```process_images``` indicating as a parameter the folder where the images and the expected results are.  Consider that the code uses the expected results to compute the precision of the output generated, which means that those expected results are needed for a proper execution.  The ```csv``` file included in the ```images_dataset``` folder can be used as an example of how said results have to be formated.

As an execution example, using the ```image_dataset``` provided, the script can be run by the following command:

```process_images('image_dataset/WormImages', 'image_dataset/WormDataA.csv');```

The code will then generate the visualization of each image and save the results in a newly created folder called ```results```.

## Implementation Details
  
### Image Analysis
Before starting to explain the proposed solution, it is necessary to analyze the images to be analyzed, since their characteristics are very relevant when it comes to understanding certain difficulties encountered in the implementation of the solution.  I will do this analysis based on the following image:
![image](https://github.com/mireiagasco/WormDetection_VC/assets/63343593/aff4ebdb-e927-41d7-857c-0cf3ec0a2882)
All the images to be treated have the same structure: they consist of a black background and, in the center, the visualization of the worms under the microscope, where the background is lighter and the worms appear darker.  Since the light is the microscope's own, we don't have homogeneous lighting, which generates shadows in the outermost part of the visualization, while the central part has reflections and much more light.  This is far from ideal lighting, which should be diffused to avoid shadows and reflections.
In addition to this situation we have the problem posed by the distribution of worms.  This is seen in three key cases.  The first are the worms that are in the outer part of the visualization, where most of the shadows are.  In these cases, the pre-processing of the images will need to be fine-tuned in order to detect these worms and prevent them from being confused by backgrounds.  The second problematic situation is that in many cases the worms overlap, which makes it difficult to differentiate them. Finally, the third problem we encounter is that the image, in addition to showing worms, also contains impurities of considerable size that are very similar in color to the worms, which can lead to false positives.

### Design of the solution
#### Preprocessing
When doing the preprocessing, the first thing to do was to improve the contrast so that worms in dark areas could be detected more easily.  Both equalization and normalization were tested using various parameters, in order to see which of the two techniques could be more useful. Finally, it was determined that adaptative equalization was the most suitable technique to obtain good results, since it greatly improved the differentiation between the majority of worms and the background of the microscope.
Below you can see the equalized image 12:
![image](https://github.com/mireiagasco/WormDetection_VC/assets/63343593/18b39726-a512-49c2-947f-06ceca81c8ca)
Once the contrast was improved, the next step was to binarize the images to obtain the worms.  Tests were made with different threshold values, to see which allowed to obtain a better extraction of the worms.  The key was to get the most definition in the worms without gaining too much noise from the works caused by the lighting.  The best result obtained was using 0.22 as a threshold, which gave the following results:
![image](https://github.com/mireiagasco/WormDetection_VC/assets/63343593/f03ed846-ec7b-4ea2-be22-9b39f462dd08)
As can be seen, the main problem with binarization is that if we want to get well-defined worms, we lose edge information due to shadows.  Below is the result of binarizing with more extreme thresholds to see this problem in detail:
![image](https://github.com/mireiagasco/WormDetection_VC/assets/63343593/730931d9-6f8e-4e6e-845b-1d48778d02ea)
As can be seen, at low thresholds we obtain the visualization of the area of ​​interest without interference from the shadowed areas, but at the same time we lose quality in the visualization of the worms, to the point that many disappear altogether.  On the other hand, at higher thresholds we find the opposite situation:
![image](https://github.com/mireiagasco/WormDetection_VC/assets/63343593/58654a7b-2a5b-4e55-802f-addf05f80134)
En aquest cas, els cucs que es troben en la zona ben il·luminada es veuen clarament, mentre que aquells que es troben en la zona fosca queden detectats com a fons i es perd la seva informació. 
També cal dir que aquesta situació varia molt entre imatges.  En aquest cas el problema és molt evident degut a la il·luminació d’aquesta imatge, però si agafem una altra amb una il·luminació més homogènia, podem obtenir resultats bastant millors:
![image](https://github.com/mireiagasco/WormDetection_VC/assets/63343593/7d3cfa34-68ff-44a6-a69e-9e61b2040efd)
Due to these differences, from now on I will use both images, 12 and 24 as examples, in order to see the whole range of cases found in the design of this solution, both in more 'simple' images and the 24 or more 'complicated' like the 24.
Although the initial approach was to clean the image at this point, when testing it was seen that making morphological alterations such as opening and closing the image did not improve the result, but the opposite: in many cases, these operations made different worms are detected as a single worm.  This is why in the final version of the code, there is no preprocessing step beyond binarization.

#### Feature Extraction
To extract features, what was done was an extraction of contours that allowed the worms in the image to be identified.  Using MatLab's bwboundaries function

Image 12:
![image](https://github.com/mireiagasco/WormDetection_VC/assets/63343593/ce85d6ae-df0b-42f8-a357-fc523a28c5a6)

Image 24:
![image](https://github.com/mireiagasco/WormDetection_VC/assets/63343593/67aad7fe-e70f-443a-8956-fead652bc8f2)

If we look at image 24, four problems can already be observed with this extraction.  The first is seen in the upper part, in the two intersecting worms.  In cases like these, contour extraction detects a single object, so the analysis of these two worms will be erroneous in interpreting them as if they were a single worm.  The second problem is seen in the worm in the lower left part of the image.  Being so close to the edge, the outline does not close, and is detected as an extension of the view outline. The third problem is the detection of artifacts such as worms and the fourth is the fact that the edges of the image are detected as an outline.
These last two problems can be solved by calculating the area of ​​each of the detected objects, eliminating those that are too small or too large.  After testing, it was determined that the minimum area to consider a worm was 50, while the maximum value was 5000, in order to discard only the outline of the view.
It must be said that determining the threshold for the area presents a problem similar to that of binarization, aggravated by lighting problems.  The worms that are close to the edges, due to the shadows in the area, will present poorly defined contours, and in many cases fragmented.  This results in two worms or more than a single worm being detected, and in many cases those worms of which only small fragments are detected are removed by area filtering.  That is why in the final solution we tried to reach a middle point, which eliminated the smallest areas respecting those that could be worms.  It must be taken into account, however, that this can cause false positives, as can be seen in the following images, where you can see that some impurities can pass the area filtering.

Image 12:
![image](https://github.com/mireiagasco/WormDetection_VC/assets/63343593/13c2bff9-f28f-4ea0-9181-0da92c17b6c7)

Image 24:
![image](https://github.com/mireiagasco/WormDetection_VC/assets/63343593/bafa2028-c38e-49b7-9bda-f951d96f8149)

#### Worm Classificationç
A large number of ideas were proposed for the classification of live or dead worms, the better performing one being an analysis using a linear regression approach. The strategy that obtained better results was to calculate the width of the bounding box manually using linear regression.  This idea is based on the fact that, given a set of points (the contour), its linear regression determines the 'skeleton' of the minimal rectangle that contains the points, the width of this rectangle being the sum of the distances on the straight line from the farthest points above and below the regression.  This method follows the previous approach, where we looked at how wide the rectangle was to determine if the worm was alive or dead, but doing it manually is a technique that also works on diagonally placed worms.
So the last thing to determine was what threshold to use for the width.  Since we carry over errors from previous steps, we have to keep in mind that some worms are smaller than they should be because of image shadows and errors caused in binarization and contour extraction.  That's why the threshold of 11 was set by testing and seeing which gave a better result overall, even if there were false positives.  It must be said that we have chosen to opt for live worms, this means that in most cases we will have false positives (worms marked as alive that are dead).
Below is the result for the two images we are using as an example.

Image 12:
![image](https://github.com/mireiagasco/WormDetection_VC/assets/63343593/cb4f3ffc-e851-4ae6-b758-2ee24b50db24)

Image 24:
![image](https://github.com/mireiagasco/WormDetection_VC/assets/63343593/eee34909-fa14-4771-84d8-13d04df40479)

In these images you can see that most errors are caused by the error in the detection of contours, which causes two worms to be detected where there is only one in the shaded areas, or that only one is detected worm when several intersect.  Also, because we set the live-dead classification threshold very low, some worms that are dead are marked as alive.  However, as we will see in the test game, it is with these values ​​that we achieve a better classification of the images.

# Tracking Object in Live Capture with Movi Cinema Robot
### FF Object Tracker

Apply Vision algorithms to track an object from live capture and have Movi keep it centered in frame using its gimbal. 

For exclusive use in Freefly Project Challenge.
 
 ## Project Overview
 
 Limited developement time to eight consecutive hours.
 
 ### Movi Buttons
- **TOP**: Toggle thirds demo. This is just a quick feature idea that will lock the track to rule of thirds on the Y axis, instead of center. [View in Source](x-source-tag://GetTrackingCenterDeltaIsThirds)
- **TRIGGER**: Reset track.
  
 ## Known Weaknesses

- [`VisionTrackerProcessor`] does not handle losing confidence of the track very well.
- Overall, the processor is not robust enough to handle an extensive array of dynamic frame sizes.
- No current user adjustable settings for how the Movi attempts to center an object in frame. 
- Does not handle orientation changes, so I've locked in **Landscape Right**.
- Only tested on iPhone X and iPhone XR. 

 ## Next Steps
 ### What I would like to accomplish if I had more time. 

- Ability to record videos using AVAssetWriter.
    - I was unable to take advantage of [`AVCaptureMovieFileOutput`] as I could not use with [`AVCaptureVideoDataOutput`] simultaneously.
- Currently, I am using a linear speed ramp when moving the Movi. However, I would like to try an exponential ramp instead. This may offer increased effectiveness when tracking. [View in Source](x-source-tag://CenterMoviToTrackingCenter)
- Interactive 'Rule of Thirds' grid to dial in exact position of your track in frame.
- General performance improvements.
    - Dig deep into Memory Debugger.
    - Attempt to decrease processing times and clean up concurrency models.

 ## Other Creative Ideas
 
 Initially, as I just adopted a cat, I wanted to build an autonomous cat toy robot that used a laser pointer to play with the cat. The idea was that by implementing visual maching learning (using  [`VNCoreMLRequest`] and a custom model based in Darknet YOLO), I could assess whether a cat has entered the frame. If it has, I would attempt to track the cat, turn on the laser pointer, and apply a creative algorithm that pushes the laser wherever the cat is not. After initial evaluation, implementing a custom Core ML model would increase project developement time over eight hours, so I tabled the idea.  
  
 ## Closing Notes
 
 From habit, I encapsulated my project in a workspace to allow for CocoaPods, though I did not end up using any in this demo.

 Thank you, Freefly team for letting me have some fun with your API and Movi CR! Stemming from my serious excitement over this project, it was really hard to stop developement as I just kept wanting to explore and add features.

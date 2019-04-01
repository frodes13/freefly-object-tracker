# Tracking Object in Live Capture with Movi Cinema Robot
### Movi Object Tracker

Apply Vision algorithms to track an object from live capture and have [Movi](https://gomovi.com/) keep it centered in frame using its gimbal. [See it in action.](https://vimeo.com/319092583/3d6ee56feb) 

Originally developed for use in a Freefly Project Challenge.
 
 ## Project Overview
 
 Limited development time to eight consecutive hours.
 
 ### How To Use
Use your finger to drag a rectangle over the object you want to track. It will turn orange to indicate it is currently attempting to track the detected object observation. When connected to the Movi, it will center the object in frame using its gimbal. 
 
 ### Movi Buttons
- **TOP**: Toggle thirds demo. This is just a quick feature idea that will lock the track to rule of thirds on the Y axis, instead of center. [View in Source](x-source-tag://GetTrackingCenterDeltaIsThirds)
- **TRIGGER**: Reset track.
- **CENTER**: Toggle recording.
  
 ## Known Weaknesses

- `VisionTrackerProcessor` does not handle losing confidence of the track very well.
- Overall, the processor is not robust enough to handle an extensive array of dynamic frame sizes.
- No current user adjustable settings for how the Movi attempts to center an object in frame. 
- Does not handle orientation changes, so I've locked in **Landscape Right**.
- Does not handle user permissions errors. 
- Only tested on iPhone X and iPhone XR. 

 ## Next Steps
 ### What I would like to accomplish if I had more time. 

- Currently, I am using a linear speed ramp when moving the Movi. However, there may be another solution that may offer increased effectiveness when tracking. [View in Source](x-source-tag://CenterMoviToTrackingCenter)
- Interactive 'Rule of Thirds' grid to dial in exact position of your track in frame.
- General performance improvements.
- More robust control over Movi connection.
  
 ## Closing Notes
 
 From habit, I encapsulated my project in a workspace to allow for CocoaPods, though I did not end up using any in this demo.

 Thank you, Freefly team for letting me have some fun with your API and Movi CR! Stemming from my serious excitement over this project, it was really hard to stop development as I just kept wanting to explore and add features.
 
 For more, visit [https://frodes.io](https://frodes.io)

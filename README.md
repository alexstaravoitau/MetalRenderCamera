# MetalRenderCamera
A simple app that grabs raw camera data, converts to textures and renders on screen using `Metal`.

The app uses two reusable components with (hopefully!) simple and straightforward interfaces: `MetalCameraSession` and `MTKViewController`. 

####`MetalCameraSession`
`MetalCameraSession` helps you grab raw camera data as pixel buffers with either of two pixel formats and convert it to a Metal texture (or textures). You can choose either of two pixel formats: `RGB` or `YCbCr`, `RGB` being a default option, since it produces a single texture that can be drawn on screen right away. `YCbCr` would be a better choice in some cases though, since it is a hardware native format, hence works faster and produces textures of smaller size.

####`MTKViewController`
`MTKViewController` is a `UIViewController` subclass containing a `MTKView` that renders an arbitrary texture on screen with the help of a couple of small `Metal` shaders.

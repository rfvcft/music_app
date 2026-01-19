# Building the backend

This guide explains how to build the backend for our app. We need to complete the following steps: 

- Compile a library for loading an audio buffer from .m4a audio files

- Compile our custom library **audioanalysis**

- Use Dart FFI to access the libraries


## Audio Buffer Loader


On iOS, we use the Apple framework **AVFoundation** for loading audio buffers.
The audio buffer is returned as a float* buffer for C compatability. The buffer must use a **sampling rate** of **44.1 kHz**, the sampling rate assumed in **audioanalysis**. The source files and headers are located in:

```text
ios/Runner/AudioLoader/
├── include/
│   └── AudioBufferLoader.h
├── src/
│   └── AudioBufferLoader.mm
```

- `include/AudioBufferLoader.h`: Header file for the AudioBufferLoader interface.
- `src/AudioBufferLoader.mm`: Implementation file (Objective-C++).


### 1. Create the Static Library Target
- In Xcode, go to **File > New > Target...**
- Select **Framework & Library > Static Library** 
- Name it `AudioBufferLoader`, set language to Objective-C, and finish.
- Xcode may prompt you to select a **Team** and **Organization Identifier**. These are required for code signing and bundle identification, especially if you want to run on a real device. You can use your Apple Developer account or a unique reverse-DNS string (e.g., `com.yourname`).

### 2. Configure Build Settings
- Select the new `AudioBufferLoader` target.
- Set **Base SDK** to **iOS**.
- Set **Architectures** to `arm64` (and optionally simulator architectures).
- Set **iOS Deployment Target** (e.g., 12.0 or higher).
- In **Build Phases > Compile Sources**, add `AudioBufferLoader.mm` 
- In **Build Phases > Link Binary With Libraries**, add `AVFoundation.framework`.
- In **Build Settings > Header Search Paths**, add the path to your `include/` directory (e.g., `$(PROJECT_DIR)/ios/Runner/AudioLoader/include`).

### 3. Manually build the Library (optional)
- Select the **AudioBufferLoader** scheme in the Xcode toolbar.
- Edit scheme to your desired build type (`Release`, `Profile`, `Debug`)
- Choose a real device or **Any iOS Device (arm64)** as the build destination.
- Build the target (**Product > Build** or `Cmd+B`).

### 4. Link the Library in Your App
- In your main app, i.e. `Runner` target, make sure that the lib is listed in **Build phases > Link Binaries with Libraries**. 
- Add the directory where `AudioBufferLoader.h`is in to **Build Settings > Header Search Paths**. DON'T add `AudioBufferLoader.mm` to compile sources. 
- Add force load flags in **Build Settings > Other Linker flags**: `-Wl,-u,_loadAudioBufferFromFile`, `-Wl,-u,_freeAudioBuffer`
- Having set up everything, `libAudioBufferLoader.a` is compiled automatically when compiling the main app. This means the previous step is optional.

## Custom library **audioanalysis**

### 1. Compiling 
The library has the following structure

```text
audioanalysis/
├── CMakeLists.txt 
├── build/
    ├── ios/
        └── libaudioanalysis.a
├── include/
└── src/ 
```

Inside `audioanalysis/` run the following commands:

```sh
mkdir -p build && cd build
cmake -DPLATFORM=ios -DCMAKE_BUILD_TYPE=Release ..
make
```
This will compile the library to `audioanalysis/build/ios/libaudioanalysis.a`.

### 2. Link the library in Your App
- In your main app (in XCode), add `libaudioanalysis.a` to Runner target. Select **Reference files in place**. Make sure that the lib is listed in **Build phases > Link Binaries with Libraries**. 
- Add headers to **Build Settings > Header Search Paths** 
- Add library search path in **Build Settings > Library Search Paths**. This is required because `libaudioanalysis.a` is located outside of a standard search location.
- Inside **Build Settings > Other Linker flags** add force load commands for loading the C-API functions: `-Wl,-u,_analyze_audio_buffer`, `-Wl,-u,_delete_analysis_result` (Otherwise the functions might not be pulled in by the app compiler)



## Using Dart FFI to Access the C-API

Once the buffer loader and **audioanalysis** is compiled and linked to your app, you can use Dart's Foreign Function Interface (FFI) to access them.
# Building the backend

This guide explains how to build the backend for our app. We need to complete the following steps: 

- Compile a library for loading an audio buffer from .m4a audio files

- Compile Essentia for iOS 

- Compile C-API for accessing the data computed by Essentia

- Use Dart FFI to access the audio loader and C-API 


## Compiling an audio buffer loader


On iOS, we use the Apple framework **AVFoundation** for loading audio buffers.
The audio buffer is returned as a float* buffer for C compatability.
The source files and headers are located in:

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

### 2. Add Source and Header Files
- Add your `AudioBufferLoader.mm` (Objective-C++) and `AudioBufferLoader.h` files to the new target.
- Make sure they are in the correct location (e.g., `src/` and `include/` folders) and added to the target membership.

### 3. Configure Build Settings
- Set **Base SDK** to **iOS**.
- Set **Architectures** to `arm64` (and optionally simulator architectures).
- Set **iOS Deployment Target** (e.g., 12.0 or higher).
- In **Build Phases > Compile Sources**, ensure only `AudioBufferLoader.mm` is listed (remove any `.m` stubs).
- In **Build Phases > Link Binary With Libraries**, add `AVFoundation.framework`.
- In **Build Settings > Header Search Paths**, add the path to your `include/` directory (e.g., `$(PROJECT_DIR)/ios/Runner/AudioLoader/include`).

### 4. Build the Library
- Select the **AudioBufferLoader** scheme in the Xcode toolbar.
- Choose a real device or **Any iOS Device (arm64)** as the build destination.
- Build the target (**Product > Build** or `Cmd+B`).

### 5. Locate the Output
- In the Project Navigator, expand the **Products** group under your library target.
- Right-click `libAudioBufferLoader.a` and select **Show in Finder**.
- The file will be in `~/Library/Developer/Xcode/DerivedData/<YourProjectName>-<random>/Build/Products/Release-iphoneos/`.

### 6. Link the Library in Your App
- In your main app (in XCode), add `libAudioBufferLoader.a` to Runner target. Select **Reference files in place**. Make sure that the lib is listed in **Build phases > Link Binaries with Libraries**. 
- Add headers to **Build Settings > Header Search Paths** 
- The buffer loader will later be accessed via Dart FFI. 


## Compiling Lightweight Essentia 2.1-beta5 for iOS

### Directory Layout for Essentia

The `essentia/` folder is organized as follows:

```text
essentia/
├── android/					 # Location of analogous Android installs (TODO)
├── essentia_c_api/				 # C-API source files for accessing Essentia
│   ├── include/
│   │   ├── algorithms.h
│   │   └── c_api.h
│   └── src/
│       ├── algorithms.cpp
│       └── c_api.cpp
├── essentia_github_repo/ 	  	 # Essentia source files, downloaded from GitHub
│   ├── .gitignore
│   ├── .gitmodules
│   ├── AUTHORS
│   ├── COPYING.txt
│   ├── README.md
│   ├── build/
│   ├── debian/
│   ├── doc/
│   ├── packaging/
│   ├── src/
│   ├── test/
│   ├── travis/
│   ├── utils/
│   ├── waf
│   └── wscript
├── ios/						# Location of iOS installs
│   ├── CMakeLists.txt.			# Use this CMake file to compile the C-API in dir below
│   ├── c_api_build/			
│   └── essentia_installation/ 	# Statically compiled Essentia for iOS
```

- `essentia_c_api/`: C API wrapper for Essentia, with headers in `include/` and implementation in `src/`.
- `essentia_github_repo/`: Main Essentia source code with build scripts. Downloaded from GitHub.
- `ios/`: iOS-specific build scripts and output.
- `android/`: Android-specific files.

This structure separates platform-specific builds, the main source, and the C API.


### 1. Configure Essentia for iOS
- Inside `essentia_github_repo/` run the following command:

```sh
python3.10 waf configure --cross-compile-ios --lightweight= --fft=ACCELERATE --build-static --prefix=../ios/essentia_installation --ignore-algos=NNLSChroma
```


- `python3.10` is used because newer versions are incompatible with Essentia 2.1-beta5
- `--ignore-algos=NNLSChroma` is required because compiling `nnls.c` does not work for iOS.
- `--lightweight=` enables the lightweight build.
- `--fft=ACCELERATE` uses Apple’s Accelerate framework for FFT.
- `--prefix=../ios/essentia_installation` installs iOS-Essentia to `essentia_installation/`


### 2. Build and Install

```sh
python3.10 waf build -j8
python3.10 waf install
```

- `-j8` use 8 cores for compiling


### 3. Link the Library in Your App
- In your main app (in XCode), add `libessentia.a` to Runner target. Select **Reference files in place**. Make sure that the lib is listed in **Build phases > Link Binary with Libraries**. 
- Add `AVFoundation.framework` in **Build Phases > Link Binary With Libraries**.
- Add headers to **Build Settings > Header Search Paths**. 
- Add library search path in **Build Settings > Library Search Paths**. This is required because `libessentia.a` is located outside of a standard search location.

## Compiling C-API for iOS

The C-API source files and headers for Essentia are located in `essentia/essentia_c_api/`. It provides a C interface to the functionalities of the Essentia library, allowing for integration through Dart FFI. 

### 1. Build C-API

```text
essentia/
├── essentia_c_api/				 # C-API source files for accessing Essentia
│   ├── include/
│   └── src/
├── essentia_github_repo/ 	  	
├── ios/						
│   ├── CMakeLists.txt.			
│   ├── c_api_build/			 # Build C-API in here, with above CMake file
│   └── essentia_installation/ 	 # Statically compiled Essentia for iOS
```

- Inside `c_api_build/` run the following commands:

```sh
cmake ..
make
```
This will compile the C-API from the C-API source files in `essentia/essentia_c_api/` and the iOS-Essentia installation in `essentia/ios/essentia_installation`. The resulting file is called `libessentia_c_api.a`.


### 2. Link the C-API in Your App
- In your main app (in XCode), add `libessentia_c_api.a` to Runner target. Select **Reference files in place**. Make sure that the lib is listed in **Build phases > Link Binaries with Libraries**. 
- Add headers to **Build Settings > Header Search Paths** 
- Add library search path in **Build Settings > Library Search Paths**. This is required because `libessentia_c_api.a` is located outside of a standard search location.
- Inside **Build Settings > Other Linker flags** add force load commands for loading the C-API functions: `-Wl,-u,_essentia_analyze_buffer`, `-Wl,-u,_delete_analysis_result` (Otherwise the functions might not be pulled in by the app compiler)
- The C-API will be accessed through Dart FFI.


## Using Dart FFI to Access the C-API

Once the buffer loader and C-API is compiled and linked to your app, you can use Dart's Foreign Function Interface (FFI) to access them.









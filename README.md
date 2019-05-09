# ATI_Log_Processor

Matlab functions that process the data from the PixHawk and a force torque sensor. The is to determine the coefficient of thrust and coefficient of torque for the motors.

An ATI Axia80 was origionally used, but currently a JR3 30E12A4 is being set up as a replacement.


## Setup

Before any test can occur, clone the repository using the --recursive option so that the submodule is cloned as well:
```
git clone --recursive https://github.com/kpdudek/ATI_Log_Processor.git
```

### Now we will setup the dependencies:
Instructions are written for a linux enviornment.

First we need to setup the python enviornment:
```
~$ sudo apt-get install python-setuptools
~$ sudo apt-get install python-dev
```
Now we can instal the ulog converter
```
~$ cd Quadrotor_Thrust_Analysis/pyulog/
~$ sudo python setup.py build install
```

## Usage

Run QGroundContol and calibrate the sensors on the quadcopter before mounting to the stand.

### Data collection on the quad must follow this procedure:
0. You will have up to three data files for a test and they must follow this naming format:
    - Choose a filename and then append a sensor identifier as follows:
    - Pix-Hawk .ulg file: filename_PX4.ulg
    - F/T Sensor .csv file: filename_FT.csv
    - Tachometer .csv file: filename_Tacho.csv
1. Arm the quadcopter and begin F/T data collection (as close to simultaneously as possible). The analysis program can handle misalignemnt of a few seconds at max
2. Move the throttle to ~10% then wait 3 seconds to let the motors equalize
3. Provide five spikes of full roll right separated by ~1 second. These bumps show up on the sensor data and allow the analysis program to find the offset between plots
4. Now, perform your test run varying throttle, roll and pitch. NOTE: A standard quad battery lasts 6-8 minutes
5. When the test run has finished, move the .ulg file from the /Log/ folder on the pix hawk's sd card. The pix-hawk names the logs numerically, so you must rename the .ulg file with the same prefix as the F/T sensor file you just recorded
6. Navigate to the folder with the pix-hawk's .ulg file and run:
    ```
    ulog2csv filename.ulg
    ```
    - This will convert the binary .ulg file into .csv files containing all logged data during the flight
    - NOTE: if you forgot to clone the repo with the recursive flag clone the submodule with:
    ```
    git submodule update --init --recursive
    ```
7. Now open matlab and set your working directory to the folder containing all of the files
    - The working directory should contain the F/T sensors .csv file and the 


### MATLAB Analysis
To get the coefficient matrix there are two scripts that must be run. The two scripts depend on if there is tachometer data in addition to the onboard/FT data.

Without tachometer data run:
    1. POC_tracks_alignment.m: parse .csv files, align timescales, save into .mat file
    2. Load .mat file from POC_tracks_alignment.m and analyze
With tachometer data, run:
    1. Tachometer_VS_ActuatorOutput.m: parse .csv files, align timescales, save into .mat file
    2. Process_Tachometer_Data.m: Load .mat file from Tachometer_VS_ActuatorOutput.m and analyze

When running the analysis script, the name of the .mat file must be manually entered.


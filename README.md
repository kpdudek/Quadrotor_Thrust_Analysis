# ATI_Log_Processor

Matlab functions that process the data from the PixHawk and ATI Force Torque sensor to find the coefficient of thrust of the motors


## Usage

Before any test can occur clone the Pyulog python package so that the .ulg files can be converted into a .csv file:
```
git clone https://github.com/PX4/pyulog.git
```

Additionally ensure that the ATINetFT.jar application runs and can connect to the sensor using the ip address. First, navigate to the cloned repository and make the application executable as follows:
```
~$ cd ATI_Log_Processor
~$ chmod +x ./ATINetFT.jar
~$ ./ATINetFT.jar

ip address: 192.168.1.241
```

Now, run QGroundContol and calibrate the sensors on the quadcopter before mounting to the stand. Connect the sensor to the dri network before plugging it in.

Data collection on the quad must follow this procedure:
```
0. Create a folder in which to store all of the files that will be created during the test run. Name it following the convention QuadName_Year_Month_Day_WhatYouManipulate_FlightMode
1. Arm the quadcopter and press "Collect Data" as close to simultaneously as possible. The analysis program can handle misalignemnt of a few seconds at max
2. Wait 3 seconds to let the motors equalize
3. Provide three spikes of full roll right separated by ~1 second. These bumps show up on the sensor data and allow the analssis program to find the offset between plots
4. Now, perform your test run
5. When the test run has finished, move the .csv file from the F/T sensor into a folder with the .ulg file from the /Log folder on the pix hawk's sd card. The pix hawk names the logs numerically, so you must rename the .ulg file to the same name as the F/T sensor
6. Navigate to /pyulog/pyulog and run: python ulog2csv /path/to/file.ulg -o /output/path
7. Now open matlab and set your working directory to the folder containing all of the files
```

1. In POC_tracks_alignment.m type in the csv filename to read from on line 2, and the filename that the output will be saved to   in line 44
2. Run POC_tracks_alignment.m

3. In POCidentification.m type in the .mat filename from step 1.
4. Run POCidentification.m


POCidentification.m outputs three sets of solutions separated by the headers "Linear system solution", "Averaging solution", and "Independent Values"

The "Linear system solution" uses matlabs backslah operator to solve the large matricies with all data points while the "averaging solution" takes the average value of each variable and then solves for the coefficient matrix.

"Independent values" solves for the coefficent of thrust for each motor rather than assuming a constant value througout the quad

# ATI_Log_Processor

Matlab functions that process the data from the PixHawk and ATI Force Torque sensor. The results are  to find the coefficient of thrust of the motors


## Usage

Before any test can occur clone the repository using the --recursive option so that the submodule is cloned as well:
```
git clone --recursive <project url>
```

Additionally ensure that the ATINetFT.jar application runs and can connect to the sensor using the ip address. First, navigate to the cloned repository and make the application executable as follows:
```
~$ cd ATI_Log_Processor
~$ chmod +x ./ATINetFT.jar
~$ ./ATINetFT.jar

ip address: 192.168.1.241
```

Now, run QGroundContol and calibrate the sensors on the quadcopter before mounting to the stand. Connect the sensor to the dri network before powering it on.

Data collection on the quad must follow this procedure:
```
0. Run ATINetFT.jar and connect to the sensor. Click on log data and create a new folder ~/ATI_Log_Processor/Test_Data/R2_Date_TestDescription_FlightMode to save the log file to.
1. Arm the quadcopter and press "Collect Data" as close to simultaneously as possible. The analysis program can handle misalignemnt of a few seconds at max
2. Move the throttle inbetween the 2nd and 3rd line then wait 3 seconds to let the motors equalize
3. Provide three spikes of full roll right separated by ~1 second. These bumps show up on the sensor data and allow the analysis program to find the offset between plots
4. Now, perform your test run varying throttle, roll and pitch
5. When the test run has finished, move the .ulg file from the /Log/ folder on the pix hawk's sd card. The pix hawk names the logs numerically, so you must rename the .ulg file to the same name as the F/T sensor file you just recorded
6. Navigate to ~/ATI_Log_Processor/pyulog/pyulog and run: python ulog2csv /path/to/file.ulg -o .
7. Now open matlab and set your working directory to the folder containing all of the files
```

1. In POC_tracks_alignment.m type in the csv filename to read from on line 2, and the filename that the output will be saved to   in line 44
2. Run POC_tracks_alignment.m

3. In POCidentification.m type in the .mat filename from step 1.
4. Run POCidentification.m


POCidentification.m outputs three sets of solutions separated by the headers "Linear system solution", "Averaging solution", and "Independent Values"

The "Linear system solution" uses matlabs backslah operator to solve the large matricies with all data points while the "averaging solution" takes the average value of each variable and then solves for the coefficient matrix.

"Independent values" solves for the coefficent of thrust for each motor rather than assuming a constant value througout the quad
